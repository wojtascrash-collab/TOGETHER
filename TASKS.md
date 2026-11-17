# TOGETHER — zadania

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
