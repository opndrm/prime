# Flujo de sandboxes Exe para OPNDRM

## Registro único

Ejecuta `ssh exe.dev` en tu propia Terminal y completa el registro. Antes de aceptar la primera conexión, verifica la huella exacta: `SHA256:JJOP/lwiBGOMilfONPWZCXUrfK154cnJFXcqlsi6lPo`. Nunca desactives la verificación de host.

## Un sandbox por tarea

Usa Exe como un constructor Linux privado y desechable para una tarea limitada de ADAM o FRNKLY.ONE. Confirma repositorio, rama, límite de escritura, pruebas y condición de parada. Usa integración GitHub con mínimo privilegio e integración LLM; nunca copies claves, identidad de Buzz ni expongas Ollama local.

```bash
ssh exe.dev new --name <tarea> --cpu=4 --memory=8G --disk=25G \
  --tag opndrm,<adam-o-frnkly-one>,task --integration <repo> --integration <llm>
```

Mantén el proxy privado. No publiques puertos ni elimines VMs sin aprobación explícita.

## Límite de la Gate

Exe ejecuta análisis, generación de código y pruebas Linux. Para ADAM y FRNKLY.ONE, No Mistakes se usa solamente después de producir una rama y la validación nativa—Xcode, simulador/dispositivo, firma y empaquetado—permanece en la Mac controlada.
