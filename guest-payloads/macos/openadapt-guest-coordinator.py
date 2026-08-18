"""Guest-only OpenAdapt coordination contract.

This module is a deliberately inert schema and state-model skeleton.  It has
no capture, input, audio, networking, process, filesystem, or entry-point
code.  It only validates and renders metadata that a future, separately
approved guest integration might use.
"""

from __future__ import annotations

from dataclasses import dataclass
from enum import Enum
from typing import Final, Mapping
import re


CONTRACT_VERSION: Final = "openadapt-guest-coordinator/v1"
MAX_ASSIGNMENT_ID_BYTES: Final = 128
MAX_RELAY_MESSAGE_BYTES: Final = 1_024
MAX_INT64: Final = (1 << 63) - 1
MAX_UINT64: Final = (1 << 64) - 1

# These are policy declarations, not enabled capabilities.  This skeleton
# deliberately contains no adapter or API for any item in this set.
FORBIDDEN_CAPABILITIES: Final = frozenset(
    {
        "audio",
        "microphone",
        "screen-capture",
        "input-capture",
        "host-capture",
        "network",
        "subprocess",
        "host-paths",
        "execution",
    }
)

_CANONICAL_LOWER_UUID = re.compile(
    r"^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"
)
_ASSIGNMENT_ID = re.compile(r"^[A-Za-z0-9._-]{1,128}$")
_STATUS_FIELDS: Final = frozenset(
    {
        "persistent_vm_id",
        "boot_epoch",
        "assignment_id",
        "sequence",
        "expiry_unix_milliseconds",
        "state",
    }
)

# This is documentation data for the metadata-only wire shape.  It names
# exactly the six relay fields; it is not a transport implementation.
METADATA_STATUS_REQUEST_SCHEMA: Final[Mapping[str, object]] = {
    "additional_properties": False,
    "fields": (
        "persistent_vm_id",
        "boot_epoch",
        "assignment_id",
        "sequence",
        "expiry_unix_milliseconds",
        "state",
    ),
    "max_utf8_bytes": MAX_RELAY_MESSAGE_BYTES,
    "content": "metadata-only",
    "prohibits": tuple(sorted(FORBIDDEN_CAPABILITIES)),
}


class RelayState(str, Enum):
    """The only status labels allowed by the metadata relay contract."""

    UNAVAILABLE = "unavailable"
    CONSENT_PENDING = "consent-pending"
    CONFIRMED_ACTIVE = "confirmed-active"
    FINALIZING = "finalizing"
    STOPPED = "stopped"
    FAILED = "failed"


class ConsentState(str, Enum):
    """A guest-visible consent display; it grants no capability by itself."""

    REQUIRED = "required"
    DECLINED = "declined"
    CONFIRMED = "confirmed"


@dataclass(frozen=True)
class VisibleConsent:
    """Text intended for a guest surface, never an implicit permission grant."""

    state: ConsentState
    visible_label: str
    visible_detail: str
    microphone_allowed: bool = False
    audio_allowed: bool = False

    def __post_init__(self) -> None:
        if not self.visible_label.strip() or not self.visible_detail.strip():
            raise ValueError("visible consent requires non-empty guest text")
        if self.microphone_allowed or self.audio_allowed:
            raise ValueError("audio and microphone are forbidden")

    @property
    def relay_state(self) -> RelayState:
        """Map the visible decision to a metadata label without performing work."""
        if self.state is ConsentState.REQUIRED:
            return RelayState.CONSENT_PENDING
        if self.state is ConsentState.DECLINED:
            return RelayState.UNAVAILABLE
        return RelayState.CONFIRMED_ACTIVE


@dataclass(frozen=True)
class TaskBootLeaseBounds:
    """Binding metadata for one VM boot and one owner-approved task/lease.

    ``assignment_id`` is the bounded task/lease reference.  There are no
    separate task or lease fields in the relay contract, which prevents an
    ambiguous cross-boot association.  ``expiry_unix_milliseconds`` is supplied
    by the binding authority; this model never treats it as guest authority.
    """

    persistent_vm_id: str
    boot_epoch: str
    assignment_id: str
    expiry_unix_milliseconds: int

    def __post_init__(self) -> None:
        _validate_uuid("persistent_vm_id", self.persistent_vm_id)
        _validate_uuid("boot_epoch", self.boot_epoch)
        _validate_assignment_id(self.assignment_id)
        _validate_expiry(self.expiry_unix_milliseconds)


@dataclass(frozen=True)
class MetadataOnlyStatusRequest:
    """Validated six-field status request with no payload or transport.

    The serialized form contains only relay binding/status metadata.  It
    cannot carry media, events, artifacts, commands, tokens, or locations.
    """

    persistent_vm_id: str
    boot_epoch: str
    assignment_id: str
    sequence: int
    expiry_unix_milliseconds: int
    state: RelayState

    def __post_init__(self) -> None:
        TaskBootLeaseBounds(
            persistent_vm_id=self.persistent_vm_id,
            boot_epoch=self.boot_epoch,
            assignment_id=self.assignment_id,
            expiry_unix_milliseconds=self.expiry_unix_milliseconds,
        )
        if type(self.sequence) is not int or not 0 <= self.sequence <= MAX_UINT64:
            raise ValueError("sequence must be an unsigned 64-bit integer")
        if not isinstance(self.state, RelayState):
            raise ValueError("state must be a RelayState")
        # The fixed six keys plus two UUIDs, a <=128-byte assignment ID, two
        # 64-bit decimal integers, and a listed state are necessarily below
        # MAX_RELAY_MESSAGE_BYTES.  No serializer or transport is present here.

    @classmethod
    def from_metadata(
        cls, metadata: Mapping[str, object]
    ) -> "MetadataOnlyStatusRequest":
        """Validate an already-decoded metadata object; no decoding or I/O occurs."""
        if set(metadata) != _STATUS_FIELDS:
            raise ValueError("status metadata must contain exactly the six allowed fields")
        try:
            state = RelayState(metadata["state"])
        except (TypeError, ValueError) as error:
            raise ValueError("state is not an allowed relay state") from error
        return cls(
            persistent_vm_id=_string_field(metadata, "persistent_vm_id"),
            boot_epoch=_string_field(metadata, "boot_epoch"),
            assignment_id=_string_field(metadata, "assignment_id"),
            sequence=_integer_field(metadata, "sequence"),
            expiry_unix_milliseconds=_integer_field(
                metadata, "expiry_unix_milliseconds"
            ),
            state=state,
        )

    def to_metadata(self) -> dict[str, object]:
        """Render the exact six-field metadata shape without sending it anywhere."""
        return {
            "persistent_vm_id": self.persistent_vm_id,
            "boot_epoch": self.boot_epoch,
            "assignment_id": self.assignment_id,
            "sequence": self.sequence,
            "expiry_unix_milliseconds": self.expiry_unix_milliseconds,
            "state": self.state.value,
        }


@dataclass(frozen=True)
class PlaceholderResult:
    """An explicit not-implemented result for a future reviewed capability."""

    phase: str
    status: str = "not-implemented"
    detail: str = "Guest-only coordinator skeleton; no action was performed."


@dataclass(frozen=True)
class GuestOpenAdaptCoordinator:
    """Inert coordinator facade that exposes consent and placeholder stages."""

    bounds: TaskBootLeaseBounds
    consent: VisibleConsent

    def status_request(self, sequence: int) -> MetadataOnlyStatusRequest:
        """Create metadata only; this method does not record, send, or execute."""
        return MetadataOnlyStatusRequest(
            persistent_vm_id=self.bounds.persistent_vm_id,
            boot_epoch=self.bounds.boot_epoch,
            assignment_id=self.bounds.assignment_id,
            sequence=sequence,
            expiry_unix_milliseconds=self.bounds.expiry_unix_milliseconds,
            state=self.consent.relay_state,
        )

    def review_placeholder(self) -> PlaceholderResult:
        return PlaceholderResult("review")

    def compile_placeholder(self) -> PlaceholderResult:
        return PlaceholderResult("compile")

    def certify_placeholder(self) -> PlaceholderResult:
        return PlaceholderResult("certify")


def _validate_uuid(name: str, value: object) -> None:
    if not isinstance(value, str) or not _CANONICAL_LOWER_UUID.fullmatch(value):
        raise ValueError(f"{name} must be a canonical lowercase UUID")


def _validate_assignment_id(value: object) -> None:
    if not isinstance(value, str) or not _ASSIGNMENT_ID.fullmatch(value):
        raise ValueError("assignment_id must use 1..128 ASCII [A-Za-z0-9._-] bytes")
    if len(value.encode("ascii")) > MAX_ASSIGNMENT_ID_BYTES:
        raise ValueError("assignment_id exceeds byte bound")


def _validate_expiry(value: object) -> None:
    if type(value) is not int or not 0 < value <= MAX_INT64:
        raise ValueError("expiry_unix_milliseconds must be a positive signed 64-bit integer")


def _string_field(metadata: Mapping[str, object], name: str) -> str:
    value = metadata[name]
    if not isinstance(value, str):
        raise ValueError(f"{name} must be a string")
    return value


def _integer_field(metadata: Mapping[str, object], name: str) -> int:
    value = metadata[name]
    if type(value) is not int:
        raise ValueError(f"{name} must be an integer")
    return value
