# TOGETHER — zadania

## Zdjęcie profilowe w Safari na iPhonie — 21 listopada 2026

- [x] Użytkownik potwierdził na fizycznym iPhonie, że w Safari da się zapisać zdjęcie profilowe z galerii. Po wylogowaniu i ponownym zalogowaniu zdjęcie nadal było widoczne.
- [x] Próbę wykonano w podglądzie wersji MVP połączonym z projektem Supabase `TOGETHER-odzyskiwanie-test` (`ocivlnwgwxqsrqpadfsu`). Osobny test w Chrome potwierdził zapis WebP i awaryjny zapis JPEG. W próbie na iPhonie nie ustalono, którego formatu użyła przeglądarka.
- [x] Po próbie usunięto konto testowe wraz z profilem i zdjęciem zapisanym w polu `public.profiles.avatar_webp`. Odczyt bazy potwierdził usunięcie konta, profilu i wpisu logowania. Tabele zachowano, a liczby spotkań i zapisów na spotkania wynosiły po 0 przed i po operacji.
- [x] Próba i usunięcie danych odbyły się w projekcie testowym. Produkcja pozostała bez zmian.

## Przygotowanie do szerszych testów — 18 listopada 2026
- [x] Odzyskiwanie hasła przez e-mail Supabase oraz ekran ustawienia nowego hasła po powrocie z linku.
- [x] Obowiązkowe potwierdzenie pełnoletności i akceptacji wersji regulaminu/polityki prywatności zapisywane na koncie.
- [x] Roboczy regulamin i polityka prywatności dostępne z każdej strony. Dokumenty jasno oznaczone jako wymagające danych administratora i weryfikacji przed publicznym/komercyjnym startem.
- [x] Nieprzeczytane wiadomości liczone dla odbiorcy; otwarcie rozmowy oznacza je jako przeczytane, zakładka pokazuje licznik.
- [x] Testy lokalne oraz kontrola zgód na docelowym Supabase w transakcji ROLLBACK.
- [ ] Panel moderatora wymaga wskazania konkretnego konta administratora; nie nadano nikomu dostępu do prywatnych zgłoszeń.

## Rozmowy, bezpieczeństwo, filtry i zdjęcia — 18 listopada 2026
- [x] Czat dostępny wyłącznie dla dwóch osób ze wzajemnego dopasowania; maks. 1000 znaków, ostatnie 200 wiadomości.
- [x] Usunięcie dopasowania usuwa rozmowę kaskadowo. Blokada usuwa kontakt i zatrzymuje ponowne wyświetlanie oraz wiadomości w obie strony.
- [x] Zgłoszenia są zapisywane prywatnie; użytkownicy nie mają bezpośredniego odczytu tabeli zgłoszeń.
- [x] Filtry miasta i zainteresowania działają po stronie bazy bez ujawniania identyfikatorów użytkowników.
- [x] Zdjęcia JPG/PNG/WebP do 2 MB w osobnym bucketcie; zapis wyłącznie we własnym folderze konta. Publiczne wyświetlanie dotyczy zdjęcia wybranego do widocznej wizytówki.
- [x] Test PGlite: prywatność rozmowy, kierunek wiadomości, blokada i brak dostępu do tabel. Test na docelowym Supabase w transakcji ROLLBACK: wzajemne dopasowanie i odczyt wiadomości z obu stron.
- [ ] Kontrola UI produkcji po publikacji oraz test przesłania zdjęcia na rzeczywistym koncie.

## Poznawanie osób i wzajemne dopasowania — 18 listopada 2026
- [x] Oddzielna wizytówka publiczna: nazwa, miasto, opis, zainteresowania i przełącznik widoczności. Bez połączenia z prywatną tabelą profiles, bez e-maila i identyfikatora konta w odpowiedziach API.
- [x] Karty „Pomiń” / „Chcę poznać”; raz oceniona karta znika z kolejki użytkownika.
- [x] Dopasowanie powstaje wyłącznie po dwóch wzajemnych wyborach; lista dopasowań jest dostępna tylko uczestnikom danego dopasowania.
- [x] Tabele mają RLS i brak bezpośrednich praw dla anon/authenticated. Operacje prowadzą przez kontrolowane RPC z auth.uid(), pustym search_path i EXECUTE wyłącznie authenticated.
- [x] 22 testy JS oraz test PGlite rozszerzony o karty, blokadę tabel, wzajemny wybór i brak pól prywatnych. Test na docelowym Supabase wykonany w transakcji zakończonej ROLLBACK.
- [ ] Kontrola ekranu produkcyjnego po wdrożeniu Vercel i test dwóch rzeczywistych sesji.

## Powiadomienia w aplikacji — 18 listopada 2026
- [x] Migracja together_participant_notifications: prywatna tabela RLS, trigger transakcyjny zmian starts_at/city/location/cancelled_at, wyłącznie zapisani uczestnicy bez organizatora. Bez danych profili i adresów e-mail.
- [x] Zapis bez zmiany wartości i powtórne odwołanie nie tworzą duplikatów. Jedna zmiana terminu i miejsca daje jedno zbiorcze powiadomienie.
- [x] Odczyt własnych powiadomień przez SECURITY INVOKER i RLS; zapis generuje tylko trigger; odczytanie przez kontrolowane RPC wyłącznie user_id=auth.uid().
- [x] Skrzynka: licznik wszystkich nieprzeczytanych, ostatnie 100 pozycji, poprzedni i nowy termin/miejsce, status przeczytania, odświeżanie co 30 s w aktywnej karcie oraz po powrocie do aplikacji. Reset skrzynki przy wylogowaniu i ochrona przed spóźnionymi odpowiedziami innej sesji.
- [x] 22 testy JS i test migracji PGlite. SQL potwierdził separację odbiorców, brak duplikatów, idempotencję przeczytania i brak dostępu anonimowego.
- [x] Dwa rzeczywiste konta: A zmieniło termin i miejsce TEST — lista uczestników, następnie odwołało; B dostało 2 powiadomienia po logowaniu. Oznaczenie jednego jako przeczytane zmniejszyło licznik do 1. A dostało 403 próbując przeczytać powiadomienie B.
- [x] Produkcja READY dpl_BbzzGmY2VzKFpSXoUtTeTTUHDz9m, https://together-profiles.vercel.app/ — treść i stan przeczytania potwierdzone po publikacji. Sesje testowe wylogowane.
- Zakres: powiadomienia wewnątrz aplikacji; nie wysyłamy e-maili, SMS ani systemowych push. Historia powstaje od wdrożenia triggera, bez odtwarzania dawnych zmian. Kontrole audytora: zamierzone RPC SECURITY DEFINER z auth.uid i pustym search_path (https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable), wcześniejsza ochrona wyciekłych haseł pozostaje bez zmian.

## Lista uczestników — 18 listopada 2026
- [x] Migracja together_event_attendees: osobne display_name w członkostwie, zapis przez together_join_event_named(uuid,text). Nie korzysta z profiles.
- [x] RPC listy zwraca tylko display_name i joined_at. Dostęp wyłącznie host_id=auth.uid(); anonimowy i uczestnik nie mają dostępu. Historyczne zapisy: „Uczestnik bez podanej nazwy”.
- [x] Formularz zapisu wyraźnie podaje odbiorcę pseudonimu (organizator); bez automatycznego pobierania nazw z profili. Wyświetlanie przez textContent.
- [x] 20/20 testów JS i rozszerzony test bazy PGlite: pseudonim, uprawnienia, pusta lista, odwołane spotkanie, historyczne wpisy i brak pól profilu.
- [x] UI z rzeczywistym Supabase: A utworzyło oznaczony test listy, B dołączyło jako TEST — Pseudonim B; A zobaczyło pseudonim i datę. B w bezpośrednim API dostało 403/42501.
- [x] Produkcja READY: dpl_qN1psygzsBSKBQu4c6Tox6N2fkoX; lista ponownie sprawdzona na https://together-profiles.vercel.app/. Wszystkie sesje testowe wylogowane. Testowe spotkanie i zapisy zachowane.
- Audytor: zamierzone RPC SECURITY DEFINER z kontrolą auth.uid(), host_id i pustym search_path; EXECUTE tylko authenticated. Reguła: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable. Bez zmian wcześniejszego ustawienia ochrony haseł z wycieków.

## Edycja i odwoływanie — 18 listopada 2026
- [x] Migracja together_event_management: kontrola organizatora, blokada wiersza, limit miejsc, status cancelled_at bez kasowania historii.
- [x] Nowy odczyt together_list_events_v2, kompatybilność starszego klienta (bez odwołanych pozycji).
- [x] UI Edytuj / Odwołaj, wypełniony formularz, potwierdzenie odwołania i status dla uczestników. Reset edycji przy wylogowaniu.
- [x] 18 testów JS, rozszerzone testy bazy PGlite i kontrole na rzeczywistej bazie w wycofywanej transakcji: organizator może, uczestnik nie może, zapisy zachowane, odwołane nie przyjmuje uczestników.
- [x] UI z prawdziwym Supabase: A zmieniło nazwę oznaczonego testowego spotkania i je odwołało; B widziało nową nazwę, a potem ODWOŁANE bez przycisków edycji.
- [x] Produkcja READY: dpl_7wN4bvaCNEXZkHEvYLLLmw4tgrv5, https://together-profiles.vercel.app/; status potwierdzony po publikacji, sesje testowe wylogowane.
- Audytor nadal sygnalizuje zamierzone RPC SECURITY DEFINER: auth.uid(), kontrola host_id, pusty search_path, EXECUTE wyłącznie authenticated. Opis reguły: https://supabase.com/docs/guides/database/database-linter?lint=0029_authenticated_security_definer_function_executable. Wcześniejsza ochrona haseł z wycieków pozostaje bez zmian.

## Aktualny stan — 18 listopada 2026
- [x] Supabase projektu yogcyrxmxuqxazwlbfna: odczyt schematu, istniejących tabel i uprawnień.
- [x] Ponowne testy klienta 18/18 i migracji w lokalnym PGlite 0.3.14.
- [x] Zastosowano migrację `together_events_module` dodającą tabele i RPC pod nazwami `together_*`; istniejące profiles, events i event_participants zachowano.
- [x] Produkcja https://together-profiles.vercel.app: konto A utworzyło spotkanie, konto B wyszukało i dołączyło. UI i baza potwierdziły 2/2 miejsc.
- [x] Kontrolowane transakcje na bazie: podwójne dołączenie, limit miejsc, odmowa bezpośredniego zapisu i anonimowego RPC; wyjście, powtórne wyjście i powrót. Transakcje wycofano.
- [x] Testy rzeczywistego logowania i prywatności dwóch profili wykonano w poprzednim etapie; oba konta testowe wylogowano także po testach spotkań.
- [ ] Wielosesyjny test współbieżności ostatniego miejsca na produkcyjnym PostgreSQL (blokada FOR UPDATE jest obecna; nie deklarujemy niezależnego testu wyścigu).
- [ ] Fizyczne iOS/Android i ścieżka potwierdzenia e-mail pozostają osobnymi testami.

Poniższe sekcje opisują wcześniejszą historię przygotowania. Raport bieżącej integracji: outputs/spotkania-raport.md w katalogu czatu.

## Wykonano lokalnie
- [x] Odnaleziono prototyp; sprawdzono Git i dokumentację.
- [x] Sprawdzono metadane i drzewo wdrożenia Vercel.
- [x] Dodano moduł wydarzeń i mobilny interfejs.
- [x] Dodano migrację, RLS, RPC i limit miejsc.
- [x] 18 testów klienta, test SQL na PGlite oraz testy przeglądarkowe na danych symulowanych przeszły.
- [x] Przygotowano CI i konfigurację Vercel.

## Do zakończenia integracji
- [ ] Uzyskać pełny URL i dostęp GitHub; porównać właściwe źródła i połączyć historię bez nadpisywania.
- [ ] Podłączyć Supabase i sprawdzić rzeczywisty schemat oraz polityki profili.
- [ ] Zastosować migrację najpierw na środowisku testowym.
- [ ] Przeprowadzić kontrolowany test Auth i dwóch kont, trzeciego konta dla pełnego wydarzenia oraz współbieżności ostatniego miejsca.
- [ ] Sprawdzić na fizycznych iOS/Android.
- [ ] Wdrożyć przetestowane preview, potwierdzić przepływ end-to-end, dopiero potem produkcję.

## Aktualizacja dostępu GitHub

Repozytorium https://github.com/wojtascrash-collab/TOGETHER jest dostępne i publiczne; potwierdzono uprawnienia zapisu. W chwili pierwszego dostępu było puste. Wcześniejsze informacje o braku dostępu opisują stan sprzed utworzenia repozytorium. Przygotowano synchronizację kodu przez API GitHub. Testy klienta (18/18) i migracji PGlite ponownie przeszły. Integracja Supabase i wdrożenie produkcyjne nadal pozostają do wykonania.
