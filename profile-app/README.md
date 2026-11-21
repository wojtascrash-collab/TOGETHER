# Zdjęcie profilowe w TOGETHER

Ten katalog zawiera trzy pliki aplikacji z projektu Vercel `together-mvp`, używanego pod adresem `together-mvp-one.vercel.app`. Wersja wyjściowa odpowiada wdrożeniu `dpl_A7JKKP2FucUPxPUGQ6Y6CUmjxYch`. Katalog `dist/` obsługuje oddzielną wersję aplikacji.

Przeglądarka przygotowuje miniaturę 160 × 160 px do 24 KiB. Najpierw próbuje WebP. Jeśli kodowanie nie daje poprawnego wyniku w limicie, używa JPEG. Edytor i lista uczestników rozpoznają format po zawartości. Oba formaty korzystają z tego samego pola `profiles.avatar_webp` i tych samych reguł dostępu.

## Wydanie

1. Uruchom `node --test tests/profile-avatar.test.js`. Przed wydaniem sprawdź zapis JPEG i jego wyświetlanie w Safari na iPhonie na środowisku testowym.
2. Po zatwierdzeniu zmiany bazy zastosuj `allow-jpeg.sql` w projekcie obsługującym tę wersję. Skrypt zmienia tylko walidację zdjęcia i działa w jednej transakcji.
3. Po zatwierdzeniu publikacji wydaj trzy pliki aplikacji na Vercel. Plik SQL i dokumentacja nie należą do paczki wdrożeniowej.

Punkt przywracania Vercel to `dpl_A7JKKP2FucUPxPUGQ6Y6CUmjxYch`. Po pojawieniu się zapisanych JPEG starsza wersja nie wyświetli ich poprawnie. W takim wypadku wersja przywracana powinna zachować odczyt JPEG. Przywrócenie starego ograniczenia bazy jest możliwe dopiero po potwierdzeniu braku JPEG. Nie usuwaj zdjęć w ramach przywracania.

## Wynik wdrożenia

21 listopada 2026 r. poprawka trafiła na produkcję w Vercel (`dpl_4cm5kfutQmPKXQvvibg4WH8DCErS`). Potwierdzono, że produkcja udostępnia poprawiony kod i że baza przyjmuje prawidłowy JPEG. Użytkownik potwierdził zapis zdjęcia profilowego na fizycznym iPhonie.
