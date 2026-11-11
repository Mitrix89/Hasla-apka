# Hasła apka

Aplikacja na **Androida i Windowsa** z dwiema częściami:

- **Hasła**: zaszyfrowany sejf haseł. Każde hasło można przypisać do aplikacji, strony albo obu naraz.
- **Opłaty i przypomnienia**: subskrypcje, rachunki i terminy (np. przegląd auta, ubezpieczenie) z przypomnieniem z wyprzedzeniem.

## Plan

1. ✅ Projekt wyglądu (makiety ekranów).
2. ✅ Aplikacja i moduł haseł: hasło główne, odcisk palca, dodawanie, edycja, usuwanie, wyszukiwanie, import z Haseł Google.
3. ✅ Opłaty i przypomnienia: cykle płatności, kalendarz, powiadomienia, import wyciągu bankowego (CSV).
4. ⏳ Synchronizacja telefon–komputer i instalatory.

## Jak pobrać i zainstalować

Każda zmiana w repozytorium automatycznie buduje aplikację (zakładka **Actions** → ostatnie uruchomienie „Testy i budowanie” → sekcja *Artifacts*):

- `hasla-apka-android`: plik `app-release.apk`. Skopiuj na telefon i otwórz (Android zapyta o zgodę na instalację z nieznanego źródła).
- `hasla-apka-windows`: folder z programem. Rozpakuj i uruchom `hasla_apka.exe`.

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

Struktura: `lib/vault` (szyfrowanie i stan sejfu), `lib/import` (import CSV), `lib/screens` (ekrany), `test/` (testy).
