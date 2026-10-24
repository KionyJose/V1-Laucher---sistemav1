# loja_feature (stub público)

Este pacote é o que entra em qualquer build feito a partir deste
repositório público: `buildLojaScreen()` só mostra um aviso de
"não disponível".

A implementação real (catálogo, scraper, download via torrent) vive
fora deste repositório, num pacote local que nunca é versionado.
Para usá-la, crie (fora do controle de versão) um
`pubspec_overrides.yaml` na raiz do projeto:

```yaml
dependency_overrides:
  loja_feature:
    path: ../loja_privada
```

Sem esse arquivo — que é o caso de qualquer clone deste repositório —
o app usa este stub e builda normalmente, sem a feature.
