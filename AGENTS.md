# Zasady pracy nad TOGETHER

- Dokumentacja i raporty po polsku. Czytaj PROJECT.md, TASKS.md i README.md.
- Aktualne zlecenie wznawia rozwój MVP wydarzeń. Zachowaj istniejący katalog, pliki i powiązania hostingu.
- Przed zmianą sprawdź git status --short i git remote -v. Nie nadpisuj cudzych zmian.
- Kod interfejsu jest w dist/. Bez nieuzasadnionej zmiany frameworka.
- Zachowaj kolumnę profiles.unsername. Nie ujawniaj prywatnych profili w katalogu wydarzeń.
- Frontend używa tylko publicznego klucza Supabase. Nie zapisuj haseł, sesji ani kluczy administracyjnych w repozytorium.
- Migracje sprawdzaj lokalnie, następnie na kontrolowanym środowisku Supabase. Nie zmieniaj istniejących polityk ani prawdziwych danych bez sprawdzenia ich stanu.
- Uruchom npm run check i npm run test:db (PGlite 0.3.14). UI sprawdzaj na lokalnym serwerze QA; nigdy nie publikuj symulowanego klienta.
- Nie publikuj nieprzetestowanego kodu. Same testy lokalne nie potwierdzają produkcyjnej integracji Auth/RLS. Raportuj ograniczenia i aktualizuj TASKS.md według dowodów.
