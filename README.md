# Quero — frontend

Lista de desejos em Flutter. A interface está em português do Brasil e funciona no navegador (layout largo e estreito). Os projetos Android e iOS já estão neste repositório, para `flutter build apk` e `flutter build ios`.

A foto e o preço não são buscados no navegador — isso esbarraria em CORS. O app fala com a [API](https://github.com/cesarwillemberg/lista-desejos-backend).

## Run locally

Flutter 3.24 or newer (developed on 3.50). Start the API first, on port 47231.

```bash
flutter pub get
flutter run -d chrome --dart-define=API_BASE=http://127.0.0.1:47231
```

`API_BASE` is the origin of the API, without a trailing slash.

| Where | `API_BASE` |
| --- | --- |
| `flutter run` / `flutter build web` talking to a separate API | `http://127.0.0.1:47231` |
| Web build served by the API itself | leave it unset. On the web, an empty value uses the page origin |
| Android emulator | `http://10.0.2.2:47231` |
| Phone on the same Wi-Fi | `http://<ip-da-máquina>:47231` |
| iOS / Android release | the public URL of the API |

```bash
flutter test
flutter build web --dart-define=API_BASE=http://127.0.0.1:47231
flutter build apk --dart-define=API_BASE=https://seu-servidor.example
flutter build ios --dart-define=API_BASE=https://seu-servidor.example
```

`flutter build ios` needs a Mac. The `ios/` and `android/` projects are already here. Android release builds have `INTERNET`. iOS allows local network HTTP (`NSAllowsLocalNetworking`); a production API should be HTTPS.

To serve the web build from the API, point `QUERO_WEB_DIR` at `build/web` and leave `API_BASE` unset for that build.

The web app uses hash routes so a refresh on GitHub Pages still opens the page. A shared list is `https://cesarwillemberg.github.io/lista-desejos-frontend/#/l/<token>`.

## What you can do

- Criar conta and Entrar with e-mail and password. The session stays on this device until Sair.
- Create, rename, and delete lists. Items belong to one list.
- Share a list. Anyone with the link can look, without an account, and mark **Reservar / Já comprei** so two people don’t buy the same gift. The owner can copy, regenerate, or revoke the link.

- Add an item with a name and a product URL. The card shows the photo and the price the API found.
- See the list and a total. Amounts in BRL use `R$ 1.299,90`. Other currencies keep their own code.
- Edit the name, the image URL, and the price. Clear the price field to mark it unavailable.
- Refresh the photo and the price from the store.
- Open the original link. Delete the item.

If the store blocks the read, the item is still saved, the photo is a placeholder, and the price says “Preço indisponível”.

## GitHub Pages

`.github/workflows/pages.yml` builds Flutter web and deploys it.

- Base path: `--base-href /lista-desejos-frontend/`
- API origin: `--dart-define=API_BASE=...` from the repository variable `API_BASE`, or the secret `API_BASE` if the variable is empty
- `web/manifest.json` is a standalone PWA (`start_url` and `scope` `./`, maskable icons) so a phone can use **Add to Home Screen** / **Adicionar à tela inicial**

The public URL, once Pages is enabled, is:

`https://cesarwillemberg.github.io/lista-desejos-frontend/`

Outfit and Fraunces are under the SIL Open Font License. See `assets/fonts/OFL-Outfit.txt` and `assets/fonts/OFL-Fraunces.txt`.
