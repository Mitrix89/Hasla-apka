# Hasła apka

Aplikacja na **Androida i Windowsa** z dwiema częściami:

- **Hasła**: zaszyfrowany sejf haseł. Każde hasło można przypisać do aplikacji, strony albo obu naraz.
- **Opłaty i przypomnienia**: subskrypcje, rachunki i terminy (np. przegląd auta, ubezpieczenie) z przypomnieniem z wyprzedzeniem.

## Plan

1. ✅ Projekt wyglądu (makiety ekranów).
2. ✅ Aplikacja i moduł haseł: hasło główne, odcisk palca, dodawanie, edycja, usuwanie, wyszukiwanie, import z Haseł Google.
3. ✅ Opłaty i przypomnienia: cykle płatności, kalendarz, powiadomienia, import wyciągu bankowego (CSV).
4. ✅ Synchronizacja telefon–komputer przez Wi-Fi i instalator na Windows.

## Jak pobrać i zainstalować

Każda zmiana w repozytorium automatycznie buduje aplikację (zakładka **Actions** → ostatnie uruchomienie „Testy i budowanie” → sekcja *Artifacts*):

- `hasla-apka-android`: plik `app-release.apk`. Skopiuj na telefon i otwórz (Android zapyta o zgodę na instalację z nieznanego źródła).
- `hasla-apka-windows-instalator`: instalator `HaslaApka-Setup-….exe`. Uruchom go, a program pojawi się w menu Start (instalacja bez uprawnień administratora).
- `hasla-apka-windows`: ten sam program bez instalatora (rozpakuj i uruchom `hasla_apka.exe`).

Program nie ma jeszcze cyfrowego podpisu, więc Windows może pokazać ostrzeżenie SmartScreen („Więcej informacji” → „Uruchom mimo to”).

## Aktualizacje

Wystarczy zainstalować aplikację raz. Potem sama sprawdza na GitHubie (zakładka **Releases**), czy jest nowsza wersja, i pokazuje na ekranie startowym kartę „Dostępna nowa wersja”. Można też sprawdzić ręcznie: **Ustawienia → Sprawdź aktualizacje**.

- **Android:** aplikacja pobiera APK i otwiera systemową instalację. Za pierwszym razem Android poprosi o zgodę „Zezwalaj z tego źródła”.
- **Windows:** aplikacja pobiera instalator, uruchamia go w tle i zamyka się; po instalacji otwiera się ponownie.
- Pobrany plik jest sprawdzany sumą kontrolną SHA-256 podaną przez GitHuba.

Jak powstaje wydanie: po scaleniu zmian do `main` z nowym numerem `version` w `pubspec.yaml` zadanie „Wydanie” publikuje release `vX.Y.Z` z instalatorem Windows i APK. APK trafia do wydania tylko wtedy, gdy jest ustawiony stały klucz podpisu (sekret `ANDROID_KEYSTORE_BASE64`), bo inaczej telefon odrzuciłby aktualizację. Aplikacja czyta wydania bez logowania, więc repozytorium musi być publiczne (albo wydania trzeba publikować w osobnym publicznym repozytorium i zbudować aplikację z `--dart-define=UPDATE_REPO=wlasciciel/repo`).

## Stały podpis APK (jednorazowa konfiguracja)

Android instaluje aktualizację tylko wtedy, gdy jest podpisana tym samym kluczem co poprzednia wersja.
Bez tej konfiguracji każde budowanie na GitHubie ma inny klucz i przed aktualizacją trzeba odinstalować aplikację (co kasuje jej dane).

1. Na komputerze z Javą utwórz klucz (zapamiętaj hasło i **zachowaj plik w bezpiecznym miejscu**, bo bez niego nie wydasz aktualizacji):
   ```sh
   keytool -genkeypair -keystore hasla-apka.jks -alias hasla-apka -keyalg RSA -keysize 4096 -validity 36500
   ```
2. Zamień go na tekst: `base64 -w0 hasla-apka.jks` (Windows PowerShell: `[Convert]::ToBase64String([IO.File]::ReadAllBytes("hasla-apka.jks"))`).
3. Na GitHubie: Settings → Secrets and variables → Actions → **New repository secret**, dodaj trzy sekrety:
   - `ANDROID_KEYSTORE_BASE64`: tekst z kroku 2,
   - `ANDROID_KEYSTORE_PASSWORD`: hasło z kroku 1,
   - `ANDROID_KEY_ALIAS`: `hasla-apka`.

Od następnego budowania APK będzie zawsze podpisany tym kluczem. Ostatni raz trzeba odinstalować starą wersję.

## Kategorie haseł

Na liście haseł możesz utworzyć własne kategorie (np. „Bank”, „Praca”, „Gry”): przycisk **Utwórz kategorię** pod wyszukiwarką albo menu **⋮ → Zarządzaj kategoriami**. W haśle przycisk **Dodaj do…** pokazuje wszystkie kategorie; jedno hasło może być w kilku naraz. Kategorie pod wyszukiwarką działają jak filtr. Usunięcie kategorii nie usuwa haseł.

Kategorie synchronizują się z drugim urządzeniem, dlatego synchronizacja wymaga tej samej wersji aplikacji (1.3.0 lub nowszej) na obu urządzeniach.

## Import z Haseł Google

1. Na komputerze: [passwords.google.com](https://passwords.google.com) → Ustawienia → **Eksportuj hasła**.
   Na telefonie: Ustawienia → Google → Menedżer haseł → ustawienia → **Eksportuj hasła**.
2. W aplikacji: Hasła → menu ⋮ → **Importuj z Haseł Google** → wybierz plik CSV.
3. **Usuń plik CSV** zaraz po imporcie: zawiera hasła zwykłym tekstem.

Duplikaty (ten sam login, hasło i strona) są pomijane, więc import można powtórzyć bez obaw.

## Opłaty i przypomnienia

- Trzy rodzaje pozycji: **subskrypcja** (np. Netflix), **rachunek** (np. Vectra, prąd) i **przypomnienie** (np. przegląd auta, OC).
- Cykl: co miesiąc, co kwartał, co rok albo jednorazowo. Przypomnienie: od 1 dnia do miesiąca przed terminem.
- Subskrypcje pobierają się same, więc ich termin przesuwa się automatycznie. Rachunki i przypomnienia czekają, aż klikniesz **Zapłacone / Załatwione**.
- Na ekranie startowym widać to, co zbliża się w oknie przypomnienia albo jest po terminie.
- **Powiadomienia** na Androidzie przychodzą o 9:00 w dniu przypomnienia. Na Windowsie przypomnienia widać w aplikacji (system nie pozwala programom bez instalatora MSIX odwoływać zaplanowanych powiadomień).

### Import wyciągu z banku

W bankowości internetowej pobierz historię rachunku z ostatnich 6–12 miesięcy jako **CSV**, a potem w aplikacji: Opłaty → menu ⋮ → **Importuj wyciąg z banku**. Aplikacja rozpoznaje kolumny z datą, kwotą i opisem (działa z eksportami m.in. mBanku i PKO, także w kodowaniu Windows-1250), szuka wydatków powtarzających się co miesiąc, kwartał lub rok i pokazuje je do zaznaczenia. Plik nie opuszcza urządzenia.

## Synchronizacja telefon–komputer

Oba urządzenia muszą być w tej samej sieci Wi-Fi.

1. Na komputerze: ikona synchronizacji na ekranie startowym → **Pokaż kod**.
2. Na telefonie: ikona synchronizacji → **Zeskanuj kod QR** (albo przepisz kod tekstowy).
3. Gotowe: oba urządzenia mają te same hasła i opłaty.

Nowe wpisy z obu stron są łączone, przy zmianie tego samego wpisu wygrywa nowsza wersja, a usunięcie na jednym urządzeniu usuwa wpis także na drugim.
Dane idą bezpośrednio między urządzeniami (bez internetu i chmury), zaszyfrowane AES-256-GCM kluczem z jednorazowego kodu, który działa 3 minuty.
Każde urządzenie może mieć inne hasło główne.

Przy pierwszej synchronizacji Windows może zapytać o zaporę sieciową: zezwól na dostęp w **sieciach prywatnych**.

## Bezpieczeństwo

- Hasła i opłaty są zapisane w jednym zaszyfrowanym pliku `sejf.hasla` w folderze danych aplikacji.
- Klucz powstaje z hasła głównego funkcją **Argon2id** (19 MiB pamięci, 2 iteracje), a dane są szyfrowane **AES-256-GCM** z nowym losowym nonce przy każdym zapisie.
- Hasło główne nie jest nigdzie zapisywane. **Jeśli je zapomnisz, nie da się odzyskać haseł.**
- Odcisk palca (Android): klucz sejfu trafia do magazynu Android Keystore, a jego odczyt wymaga potwierdzenia biometrią.
- Sejf blokuje się sam po minucie w tle. Skopiowane hasło znika ze schowka po 30 sekundach.
- Na Androidzie aplikacja blokuje zrzuty ekranu i nie trafia do kopii zapasowej Google.

To projekt prywatny, bez zewnętrznego audytu bezpieczeństwa.

## Dla programisty

Flutter 3.47 (stable).

```sh
flutter pub get
flutter test
flutter run -d windows   # albo podłączony telefon z Androidem
```

Struktura: `lib/vault` (szyfrowanie i stan sejfu), `lib/import` (import CSV), `lib/sync` (synchronizacja), `lib/update` (aktualizacje), `lib/screens` (ekrany), `test/` (testy).
