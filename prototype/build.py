"""Собирает файлы прототипа-артефакта из исходников приложения.

phone.html — копия веб-приложения (app/index.html) под рамку iPhone.
watch.html — веб-копия приложения для часов с общими с приложением рисунками цыпы.
Запуск: python3 prototype/build.py
"""
import pathlib

root = pathlib.Path(__file__).resolve().parent.parent
app = (root / "app" / "index.html").read_text(encoding="utf-8")

# ---- телефон: рамка уже рисует статус-бар и полоску, поэтому задаём отступы явно
phone = app
for line in ['<link rel="manifest" href="manifest.webmanifest">\n',
             '<link rel="icon" type="image/png" href="icons/icon-192.png">\n',
             '<link rel="apple-touch-icon" href="icons/apple-touch-icon.png">\n']:
    assert line in phone, line
    phone = phone.replace(line, "")
phone = phone.replace("</head>", "<style>:root { --sat: 50px; --sab: 22px; } .screen-area { box-shadow: none; }</style>\n</head>", 1)
(root / "prototype" / "phone.html").write_text(phone, encoding="utf-8")

# ---- часы: тот же рисунок цыпы и те же цвета, что в приложении
def cut(start, end):
    a = app.index(start)
    return app[a:app.index(end, a)]

watch = (root / "prototype" / "watch.src.html").read_text(encoding="utf-8")
watch = watch.replace("__BIRD__", cut("  function bird(o) {", "  function flamingo()"))
watch = watch.replace("__LOOKS__", cut("  var LOOKS = {", "  var PRODUCTS = ["))
(root / "prototype" / "watch.html").write_text(watch, encoding="utf-8")
print("phone.html", len(phone), "watch.html", len(watch))
