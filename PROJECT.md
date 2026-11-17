# TOGETHER — stan projektu

17 listopada 2026. Użytkownik wznowił rozwój MVP. Wykorzystano istniejący prototyp lokalny; jego wcześniejszy status przygotowawczy zastępuje aktualne zlecenie.

## Źródła i dostęp

- Vercel potwierdził produkcyjny deployment `dpl_H9wprFZ5JnRrmsKRQQc8g35fGfPv`, projekt `together-mvp`, stan READY. Drzewo źródeł zwraca jeden plik src/index.html. Odczyt zawartości był obcięty; zgodność z lokalnym prototypem nie została potwierdzona.
- GitHub zwraca pustą listę repozytoriów, wyszukiwanie konta wojtascrash-collab zwraca błąd braku zasobu lub dostępu. Nie skonfigurowano zgadywanego remote.
- Lokalny prototyp zastano bez commitów i remote, z plikami nieśledzonymi. Zachowano pliki, nazwę kolumny unsername, publiczną konfigurację Supabase i identyfikator istniejącego hostingu.

## Zmiany

Dodano moduł spotkań, widoki mobilne, filtrowanie, moje wydarzenia, tworzenie, dołączanie i rezygnację. Migracja SQL izoluje zapis za RPC, kontroluje auth.uid(), terminy i pojemność. Dołączanie blokuje wiersz wydarzenia; użytkownik nie może przesłać cudzej tożsamości. Dodano konfigurację Vercel, CI, testy i dokumentację wdrożenia.

## Zweryfikowane

- 18/18 testów klienta i kontrolera z odpowiedziami symulowanymi.
- Kontrola składni modułów i serwera.
- Migracja wykonana na lokalnym PGlite 0.3.14. Testy uprawnień, blokowania bezpośrednich zapisów, limitu miejsc, idempotencji, własnych członkostw, filtrów, usunięcia konta i braku dostępu anonimowego przeszły.
- Przeglądarka, lokalny serwer QA z symulacją API, szerokości 390 i 360 px: walidacja różnych haseł, logowanie, tworzenie, wyszukiwanie, puste wyniki, dołączenie, rezygnacja i wylogowanie. Brak poziomego przepełnienia w odczycie DOM. Zapisano zrzut w paczce wynikowej.

## Ograniczenia

Nie zmieniono produkcji Vercel ani bazy Supabase. Nie wykonano testu prawdziwych kont, SMTP, RLS aktualnej bazy profili, równoczesnych połączeń do PostgreSQL ani testu na fizycznym iOS/Android. Nie utworzono aplikacji natywnych. Dostęp do repozytorium i Supabase jest konieczny do zakończenia integracji i publikacji.

## Aktualizacja dostępu GitHub

Repozytorium https://github.com/wojtascrash-collab/TOGETHER jest dostępne i publiczne; potwierdzono uprawnienia zapisu. W chwili pierwszego dostępu było puste. Wcześniejsze informacje o braku dostępu opisują stan sprzed utworzenia repozytorium. Przygotowano synchronizację kodu przez API GitHub. Testy klienta (18/18) i migracji PGlite ponownie przeszły. Integracja Supabase i wdrożenie produkcyjne nadal pozostają do wykonania.
