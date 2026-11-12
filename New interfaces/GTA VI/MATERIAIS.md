# Materiais da interface GTA VI

Originais do usuário preservados na raiz desta pasta. Materiais oficiais
baixados em `01_originais/`; camadas em `02_camadas/`; cópias de execução em
`assets/GtaVI/`, declaradas no pubspec. Não há download de artes em tempo de
execução: os cenários usados na interface acompanham o aplicativo.

## Fornecidos pelo usuário

- `jason e lucia abraçados(1).png`: 1280 × 1280, RGBA; casal usado como camada
  conjunta, sem separar os corpos sobrepostos.
- `jason e lucia COmbate(2).png`: 1896 × 2129, RGBA; imagem com cenário usada
  como referência para extração da segunda pose.
- `paisagem.jpg`: 2560 × 1440; cenário noturno com lancha, usado como fundo.
- `logo.webp`: 3840 × 2916, RGBA; referência preservada. A execução usa o logo
  transparente obtido diretamente do site oficial.

## Obtidos no site oficial da Rockstar

Página de referência: https://www.rockstargames.com/VI

Galeria: https://www.rockstargames.com/VI/media/artwork-wallpapers

- `01_originais/site-oficial.html`: cópia da página consultada para referência.
- `01_originais/jason-lucia-oficial.jpg`: arte com personagens, carro e cenário.
  Fonte: https://www.rockstargames.com/VI/_next/static/media/Jason_and_Lucia_01_landscape.12x2gvspcm_3m.jpg?akim=1&imdensity=1&imwidth=3840
- `01_originais/vice-city-oficial.jpg`: cartão ilustrado de Vice City. Guardado
  para referência e possíveis composições futuras.
  Fonte: https://www.rockstargames.com/VI/_next/static/media/Vice_City_Postcard_landscape.0v2njmlk2n-qm.jpg?akim=1&imdensity=1&imwidth=3840
- `01_originais/logo-oficial.png`: logo com transparência, copiado para
  `02_camadas/logos/logo.png` e `assets/GtaVI/logo.png`.
  Fonte: https://www.rockstargames.com/VI/_next/static/media/vi.0hxa9~pf214xe.png?akim=1&imdensity=1&imwidth=1920

## Camadas preparadas com imagegen

Ferramenta usada: imagegen integrado, por meio da skill imagegen. Os resultados
são derivados/reconstruções com IA; não são novas artes oficiais da Rockstar.
Os originais não foram sobrescritos. Prompts completos em `PROMPTS.md`.

| Arquivo | Preparação |
| --- | --- |
| `02_camadas/fundos/sunset-clean.png` | Cenário reconstruído sem pessoas e sem carro |
| `02_camadas/carros/car.png` | Carro isolado, com reconstrução das áreas ocultas e transparência |
| `02_camadas/personagens/couple.png` | Cópia do recorte fornecido pelo usuário |
| `02_camadas/personagens/combat-isolated.png` | Casal em combate extraído do cenário, com transparência |

A primeira versão usa casais como camadas conjuntas. Separar cada pessoa e
palmeiras/objetos individuais permanece um refinamento futuro; isso exige
reconstruir as partes ocultas e avaliar a fidelidade dos recortes.
