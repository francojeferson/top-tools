# Global agent instructions

## RTK

Use RTK (Rust Token Killer) to reduce shell output. If RTK is on `PATH`, use the explicit RTK form for supported commands.

- Use `rtk git`, `rtk ls`, `rtk rg`, `rtk grep`, `rtk find`, `rtk wc`, `rtk stat`, `rtk curl`, and `rtk docker` with their usual arguments. Use `rtk gradlew` for `./gradlew`.
- Use `rtk read FILE` for `cat FILE`. Use `rtk read FILE --head-lines N` for `head -n N FILE`.
- Run unsupported commands directly. Use `rtk bypass COMMAND ...` when you need unfiltered output.
- Use `rtk gain` and `rtk gain --history` to check savings. Use `rtk discover` to find missed savings in Claude Code history.
- On Windows, check the executable with `Get-Command rtk`, then run `rtk --version` and `rtk gain`. If `rtk gain` is unavailable, check for Rust Type Kit, which also uses the name `rtk`.
- On this machine, use `winget install --id rtk-ai.rtk -e --accept-source-agreements` to install RTK or `winget upgrade --id rtk-ai.rtk -e --accept-source-agreements` to update it.

## ASD-STE100 Simplified Technical English

Use ASD-STE100 Issue 9 for English technical explanations, documentation, and procedures. [Official standard](https://www.asd-ste100.org/assets/files/ASD-STE100_ISSUE9.pdf)

- Use the STE dictionary to check words, meanings, and parts of speech. Use technical names and verbs as the standard permits. Use the same term for the same item or action.
- Use active voice. Limit procedural sentences to 20 words and descriptive sentences to 25 words.
- Use the imperative form in procedures. Put conditions before the commands that depend on them. Give one instruction per sentence unless the actions occur at the same time.
- Use one topic per paragraph. Keep exact code, commands, identifiers, quotations, and messages. Use the language the user requests.
- Check the writing rules and dictionary before you claim compliance.

## PTS-BR — Português Técnico Simplificado

Quando o usuário escrever em português brasileiro ou pedir `PTS-BR`, aplique o PTS-BR a explicações técnicas, documentação e procedimentos em português brasileiro. Use o idioma que o usuário pedir para a entrega.

- Consulte as regras de escrita, o dicionário controlado e a referência de termos técnicos. [Regras](https://raw.githubusercontent.com/dvwinck/pts-br/main/02-regras.md) · [Dicionário](https://raw.githubusercontent.com/dvwinck/pts-br/main/03-dicionario.md) · [Termos técnicos](https://raw.githubusercontent.com/dvwinck/pts-br/main/04-termos-tecnicos.md)
- Use voz ativa e sujeito explícito. Use o mesmo termo para o mesmo conceito. Escreva frases de procedimento com até 20 palavras e frases descritivas com até 25 palavras.
- Em procedimentos, coloque a condição antes da ação. Use o imperativo. Dê uma instrução por passo, exceto se as ações ocorrerem ao mesmo tempo.
- Preserve os valores, as datas e as condições. Mantenha o texto exato de código, comandos, identificadores, citações e mensagens.
- Verifique as regras e o dicionário antes de declarar conformidade.
