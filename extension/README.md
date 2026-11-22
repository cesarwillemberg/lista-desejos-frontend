# Extensão Wishly

Popup para o Chrome, o Edge e o Firefox. Você entra com a mesma conta da Wishly, escolhe a lista e guarda a aba aberta. A publicação na Chrome Web Store fica para quando você quiser; aqui dá para carregar a pasta direto.

## Instalar sem a loja

1. Abra `chrome://extensions` (ou `edge://extensions`).
2. Ative o **Modo do desenvolvedor**.
3. Clique em **Carregar sem compactação** e escolha esta pasta `extension`.

No Firefox: `about:debugging` → **Este Firefox** → **Carregar extra temporário** → selecione `manifest.json`.

A API em produção precisa estar no ar. O endereço padrão do popup é `https://lista-desejos-backend.onrender.com`. O backend aceita origens `chrome-extension://` e `moz-extension://`.

## Pacote

```bash
bash build.sh
```

Isso cria `wishly-extension.zip` nesta pasta.

## iPhone

O iOS não instala esta extensão. Na página da Wishly, em **Adicionar da web** (`#/compartilhar`), há um marcador para colar na barra de favoritos. Ele abre a Wishly com o link da página atual.
