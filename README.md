# VerificandoUsuarios
## Script criado para validar se existes usuários locais criados nas maquinas informadas.

### Valida se existem usuários excluindo os padrões (Administrador, Convidado, etc...)

Para tornar este código um executável vamos utilizar o comando 

##### ps2exe.ps1 -inputFile $SCRIPT_PATH\descobreUsuariosAtivos.ps1  -outputFile $OUTPUT_PATH\VerificarUsuarios.exe -noConsole -iconFile $ICON_PATH\favicon.ico
