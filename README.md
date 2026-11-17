# TOGETHER — MVP spotkań

Aktualizacja: 17 listopada 2026. Rozwój wznowiony na podstawie bieżącego zlecenia. Istniejący prototyp kont i profili rozbudowano o wydarzenia bez zmiany frameworka i kolumny `profiles.unsername`.

## Uruchomienie

Node.js 22+: `node preview.mjs`, następnie http://127.0.0.1:4173. Bez instalacji zależności produkcyjnych. Źródła aplikacji znajdują się w `dist/`. `dist/config.js` zawiera wyłącznie publiczny adres Supabase i klucz publishable.

## Funkcje w kodzie

- Rejestracja, potwierdzenie e-mail, logowanie, odnowienie sesji, wylogowanie, prywatny profil.
- Tworzenie spotkania: opis, miasto, publiczne miejsce, kategoria, data i liczba miejsc.
- Wyszukiwanie po tekście, mieście i kategorii; filtr moich spotkań; najbliższe 100 wyników.
- Dołączanie i rezygnacja. Organizator zajmuje jedno miejsce. Zapis w RPC blokuje wiersz wydarzenia, aby chronić limit miejsc; powtórne dołączenie i wyjście są idempotentne.
- Responsywny interfejs dotykowy pod przeglądarki iOS i Android. To aplikacja webowa, nie paczki App Store / Google Play; nie deklarujemy testów na fizycznych urządzeniach ani działania offline.

## Baza i migracja

`supabase/migrations/202611170001_events.sql` dodaje nowe tabele i funkcje. Nie zmienia istniejących profili. Przed zastosowaniem: sprawdzić kopię bazy, zgodność nazw oraz wykonać migrację na oddzielnym projekcie testowym Supabase. Następnie test dwóch kontrolowanych kont i dopiero wdrożenie produkcyjne.

Migracja nie została uruchomiona na docelowym Supabase. Wymaga dostępu do projektu przez połączenie Supabase. Sam klucz publiczny nie uprawnia do migracji. Nie wklejać kluczy administracyjnych do czatu, plików ani frontendu.

Tabele mają RLS. Klient otrzymuje SELECT, bez bezpośredniego INSERT/UPDATE/DELETE. Funkcje modyfikujące mają pusty search_path, jawne nazwy schematów, kontrolę auth.uid() i ograniczony EXECUTE. Nie przyjmują ID użytkownika od klienta. Uczestnik odczytuje tylko własny zapis członkostwa. Odczyt spotkań wymaga zalogowania. Profil pozostaje prywatny.

## Testy

- `npm run check` lub bez npm: `node --check preview.mjs`, `node --check dist/app.js`, `node --check dist/client.js`, `node --check dist/config.js`, `node --check dist/events.js`, `node --test tests/*.test.js`.
- Test bazy: `npm install --no-save --ignore-scripts @electric-sql/pglite@0.3.14`, potem `npm run test:db`. Opcjonalnie `node tests/database.mjs ABSOLUTNA_SCIEZKA_DO_PGLITE/dist/index.js`.
- Lokalny podgląd z symulowanym API: `node tests/preview-fixture.mjs` → http://127.0.0.1:4174. Służy tylko QA, nie łączy się z Supabase. Nigdy nie publikować testowego serwera zamiast aplikacji.
- CI uruchamia kontrolę składni, testy klienta i test bazy.

Test PGlite sprawdza rzeczywisty SQL PostgreSQL i uprawnienia przy minimalnym lokalnym schemacie auth. Nie testuje serwisu Auth, dostarczania e-maili, docelowych polityk profili ani współbieżności wielu połączeń produkcyjnych.

## Bramka publikacji

1. Udostępnić właściwe repozytorium GitHub połączeniu Codex i podać pełny URL. Obecny katalog Git nie ma remote; nie zgadujemy nazwy repozytorium. Nie potwierdzono zgodności odzyskanego prototypu z oryginalnym źródłem demonstracji Vercel.
2. Podłączyć Supabase; sprawdzić istniejące polityki profili oraz zastosować migrację na projekcie testowym.
3. Dwa konta A/B: rejestracja i potwierdzenie, trwałość sesji/profilu, A tworzy wydarzenie z capacity=2, B wyszukuje i dołącza, ponowne dołączenie nie zwiększa licznika, rezygnacja zwalnia miejsce. Konto C nie mieści się w pełnym wydarzeniu. Sprawdzić równoczesne zapisy B/C na ostatnie miejsce.
4. Sprawdzić odmowę modyfikacji cudzych profili i członkostw oraz odczytu anonimowego przez REST.
5. Ustawić dozwolone przekierowania Auth i Site URL dla preview i produkcji. Sprawdzić potwierdzenie adresu na telefonie. Potwierdzenie z e-maila wymaga powrotu do aplikacji i logowania.
6. Dopiero po przejściu testów wdrożyć preview Vercel i zweryfikować główny przepływ. `vercel.json` wskazuje dist i nagłówki ochronne. Nie promować nieprzetestowanej wersji.

Istniejące powiązanie `.openai/hosting.json` zachowano, ale nowe wdrożenie Sites nie jest częścią tego zadania. Docelowy hosting: istniejący Vercel. Raport: `PROJECT.md`, zadania: `TASKS.md`.

## Aktualizacja dostępu GitHub

Repozytorium https://github.com/wojtascrash-collab/TOGETHER jest dostępne i publiczne; potwierdzono uprawnienia zapisu. W chwili pierwszego dostępu było puste. Wcześniejsze informacje o braku dostępu opisują stan sprzed utworzenia repozytorium. Przygotowano synchronizację kodu przez API GitHub. Testy klienta (18/18) i migracji PGlite ponownie przeszły. Integracja Supabase i wdrożenie produkcyjne nadal pozostają do wykonania.
