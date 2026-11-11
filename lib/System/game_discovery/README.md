# Buscar jogos instalados

A referência principal desta adaptação é o DLSS 5 Manager:

- [GameScanner.fs](https://github.com/NODIX-TECH/DLSS-5-MANAGER/blob/main/Services/GameScanner.fs): descoberta por launcher e arte pelo identificador do jogo.
- [GameAnalyzer.fs](https://github.com/NODIX-TECH/DLSS-5-MANAGER/blob/main/Services/GameAnalyzer.fs): distinguir executáveis de jogos de instaladores, helpers e launchers usando contexto da pasta e metadados do executável.
- [IconExtractor.fs](https://github.com/NODIX-TECH/DLSS-5-MANAGER/blob/main/Services/IconExtractor.fs): extração de ícones em alta resolução e cache em PNG.

As estratégias foram reimplementadas em Dart para o V1 Launcher. O buscador não
depende dos binários nem dos assets desses projetos. Os leitores GOG/Epic também
consideram os formatos usados nas integrações do
[Playnite](https://github.com/JosefNemec/PlayniteExtensions/tree/master/source/Libraries).

## Fontes

| Fonte | Descoberta e abertura | Ícone e fundo |
| --- | --- | --- |
| Steam | Registro do cliente, `libraryfolders.vdf` moderno/legado, `config.vdf`, todos os `appmanifest_*.acf`; registro `Steam App <id>` como complemento. Abre por AppID. | `DisplayIcon` registrado, imagens em `appcache/librarycache/<id>` e formato legado. Executável como fallback. Banner oficial por AppID quando falta arte local. |
| Epic | `.item` e `LauncherInstalled.dat`; AppName/namespace/item ID. Abre pelo protocolo Epic. | Executável declarado no manifesto e imagens da instalação. |
| GOG | Registro de desinstalação e `goggame-<id>.info`; tarefa primária com argumentos e diretório de trabalho. DLCs não viram jogos separados. | Ícone registrado, `goggame-<id>.ico`, executável e imagens locais. |
| Microsoft Store | AppsFolder, família do pacote registrada e `AppxManifest.xml`. Abre pelo identificador do Shell. | PNGs declarados no manifesto, inclusive variantes `targetsize`/`scale`; ícone nativo como fallback. |
| Xbox / Game Pass | Pacotes registrados e `XboxGames/.../Content/MicrosoftGame.config`. Mantém a ação registrada do Windows para Gaming Services/autenticação. | `ShellVisuals`: logos e splash screen do próprio pacote. |
| Área de Trabalho | Desktop atual/redirecionado e público, atalhos `.lnk`/`.url` e `.exe`. | Ícone customizado do atalho, `IconFile`/`IconIndex` de `.url`, arquivo alvo e ícone do Shell. |
| Outros | Registro, pastas `Games`/`Jogos` em discos locais/removíveis. | Recursos do executável e imagens da pasta. |

Cada fonte conclui sua leitura completa. Não existe limite de 500 itens nem
prazo de seis segundos que interrompa a Steam. As fontes são paralelas e a tela
recebe seus resultados conforme terminam. Uma falha em um manifesto não elimina
os demais jogos. IDs de lojas distintas permanecem distintos, mesmo com títulos
iguais; atalhos repetidos são mesclados com os metadados da instalação.

## Arte e desempenho

A enumeração não espera extração de ícones nem downloads. Somente cards usados
pela interface carregam suas imagens. PNG/JPEG/WebP/BMP são decodificados pelo
Flutter. ICO/EXE/DLL usam o núcleo de tarefas do projeto local `nav_flutuante`:
`ExtractIconExW`, bitmap top-down criado com o DC da tela, `DrawIconEx`,
reconstrução de alfa pela máscara e `decodeImageFromPixels`. O índice do recurso
é preservado. A extração por `PrivateExtractIconsW` e pelo Shell permanece como
fallback. Atalhos resolvidos também passam a vincular o item de "Outros" ao
ícone da janela real aberta. A versão do cache foi alterada para refazer ícones
produzidos pelo extrator anterior.
Os PNGs extraídos são cacheados em `%LOCALAPPDATA%/V1 Launcher/cache/game-icons`,
com chave que inclui caminho, índice, tamanho, data de modificação e versão do
extrator. Até três extrações de arquivos rodam juntas.

Os serviços de janelas abertas continuam disponíveis como complemento, com cache
por HWND; a detecção dos jogos instalados e seus ícones não depende de o jogo
estar em execução. A interface possui clones das imagens do cache, descartados
quando o card é desmontado.

O cadastro preserva argumentos e diretório de trabalho. O leitor do banco divide
cada campo apenas no primeiro `: `, preservando títulos como
`TBH: Task Bar Hero` e argumentos que também contenham esse delimitador.

Esta integração lista instalações locais; bibliotecas de contas não instaladas
exigem integração autenticada separada. A validação de execução permanece com
o usuário; nesta alteração foi usada somente análise estática, sem testes.
