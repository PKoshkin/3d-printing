# 3D-печать

Детали для принтеров друга. Модели пишутся кодом на OpenSCAD: Павел описывает
деталь словами, Claude её проектирует, скрипт собирает файлы для печати и превью.

## Установка (один раз)

```bash
brew install --cask openscad@snapshot
```

```bash
git clone https://github.com/BelfrySCAD/BOSL2.git ~/Documents/OpenSCAD/libraries/BOSL2
```

Нужен именно snapshot: стабильная версия 2021.01 устарела и рендерит в разы
медленнее. Ещё нужен `uv` — он сам ставит зависимости скрипта сборки.

## Команды

```bash
make build PART=tolerance-test   # 3MF, STL, превью и проверки → parts/tolerance-test/out/
make all                         # то же для всех деталей
make open PART=tolerance-test    # открыть деталь в окне OpenSCAD
```

Сборка проверяет, что сетка замкнутая, деталь влезает на стол (`BED` в
`lib/printer.scad`) и OpenSCAD не выдал предупреждений. Превью с четырёх сторон
лежит в `out/preview.png`.

## Смотреть и править

- В окне OpenSCAD включи **Design → Automatic Reload and Preview**: когда Claude
  правит файл, модель обновляется сама.
- **Window → Customizer** — параметры детали полями и ползунками. Поменял →
  F6 (рендер) → **File → Export → 3MF**.
- Как деталь будет печататься (слои, поддержки, время, расход пластика), покажет
  слайсер: Bambu Studio, OrcaSlicer или PrusaSlicer, лучше тот же, что у друга.

## Что отправлять другу

`out/<name>.3mf` (или `.stl`, если с 3MF что-то не так) и карточку `README.md` из
папки детали. G-code не нужен: его друг сделает сам под свой принтер и пластик.

## Раскладка

```
parts/<name>/<name>.scad   исходник детали
parts/<name>/README.md     карточка для друга: что это и как печатать
parts/<name>/out/          результаты сборки (не в git)
lib/printer.scad           общие константы: стол, сопло, зазоры
tools/build.py             экспорт, превью, проверки
```
