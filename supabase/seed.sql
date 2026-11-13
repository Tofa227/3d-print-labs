-- TOFA3D Studio: стартовые данные. Запускать после schema.sql.

insert into public.categories (id, name, sort) values
  ('home', '{"hu":"Otthon","en":"Home","ru":"Дом"}'::jsonb, 0),
  ('desk', '{"hu":"Asztal","en":"Desk","ru":"Стол"}'::jsonb, 1),
  ('play', '{"hu":"Játék","en":"Play","ru":"Игры"}'::jsonb, 2),
  ('parts', '{"hu":"Alkatrész","en":"Parts","ru":"Детали"}'::jsonb, 3)
on conflict (id) do nothing;

insert into public.materials (id, pct, s, h, f, temp, use, sort) values
  ('PLA', 0, 3, 1, 1, 55, '{"hu":"Dekor, játék, minden, ami nem melegszik.","en":"Decor, toys, anything that stays cool.","ru":"Декор, игрушки, всё, что не греется."}'::jsonb, 0),
  ('PETG', 10, 4, 2, 2, 75, '{"hu":"Tartók, mechanikus alkatrész, konyhai és kültéri használat.","en":"Holders, mechanical parts, kitchen and outdoor use.","ru":"Держатели, механические детали, кухня и улица."}'::jsonb, 1),
  ('ABS', 15, 4, 3, 2, 95, '{"hu":"Hőt álló, strapabíró tárgyak.","en":"Heat-tolerant, durable objects.","ru":"Термостойкие прочные изделия."}'::jsonb, 2),
  ('ASA', 20, 4, 3, 2, 95, '{"hu":"Kültér, UV-álló, napfénynek kitett részek.","en":"Outdoor, UV-stable, parts exposed to sun.","ru":"Улица, стойкость к UV, детали под солнцем."}'::jsonb, 3)
on conflict (id) do nothing;

insert into public.colors (id, hex, name, sort) values
  ('graphite', '#2d2f36', '{"hu":"Grafit","en":"Graphite","ru":"Графит"}'::jsonb, 0),
  ('white', '#eeeeea', '{"hu":"Fehér","en":"White","ru":"Белый"}'::jsonb, 1),
  ('orange', '#ff6a1a', '{"hu":"Narancs","en":"Orange","ru":"Оранжевый"}'::jsonb, 2),
  ('blue', '#2f6bff', '{"hu":"Kék","en":"Blue","ru":"Синий"}'::jsonb, 3),
  ('green', '#2fbf71', '{"hu":"Zöld","en":"Green","ru":"Зелёный"}'::jsonb, 4),
  ('red', '#e5384b', '{"hu":"Piros","en":"Red","ru":"Красный"}'::jsonb, 5),
  ('grey', '#8a8f99', '{"hu":"Szürke","en":"Grey","ru":"Серый"}'::jsonb, 6)
on conflict (id) do nothing;

insert into public.products (id, shape, cat, price, name, descr, active, photo, sort) values
  ('vase', 'vase', 'home', 2990, '{"hu":"Bordázott váza","en":"Ribbed vase","ru":"Ребристая ваза"}'::jsonb, '{"hu":"Csavart, bordázott sziluett. Dekorációnak és száraz virághoz, vízhez nem ajánlott.","en":"Twisted, ribbed silhouette. For decor and dried flowers; not recommended for water.","ru":"Закрученный ребристый силуэт. Для декора и сухоцветов, для воды не рекомендуется."}'::jsonb, true, '', 0),
  ('planter', 'planter', 'home', 2290, '{"hu":"Pozsgás cserép","en":"Succulent planter","ru":"Горшок для суккулента"}'::jsonb, '{"hu":"Kisméretű, kúpos cserép pozsgásnak vagy kaktusznak.","en":"Small tapered pot for succulents or cacti.","ru":"Небольшой конический горшок для суккулентов и кактусов."}'::jsonb, true, '', 1),
  ('lamp', 'lamp', 'home', 4490, '{"hu":"Lámpabúra","en":"Lampshade","ru":"Абажур"}'::jsonb, '{"hu":"Díszlámpa-búra. Használj LED izzót, a búra ne érjen hőforráshoz.","en":"Shade for a decorative lamp. Use an LED bulb and keep the shade away from heat sources.","ru":"Абажур для декоративной лампы. Используй LED-лампу и не ставь рядом с источниками тепла."}'::jsonb, true, '', 2),
  ('stand', 'stand', 'desk', 1890, '{"hu":"Telefontartó","en":"Phone stand","ru":"Подставка для телефона"}'::jsonb, '{"hu":"Stabil, döntött telefontartó asztalra.","en":"Stable, tilted phone stand for the desk.","ru":"Устойчивая наклонная подставка для телефона на стол."}'::jsonb, true, '', 3),
  ('hook', 'hook', 'desk', 1690, '{"hu":"Fejhallgató-akasztó","en":"Headphone hook","ru":"Крючок для наушников"}'::jsonb, '{"hu":"Fejhallgató-akasztó lapos hátlappal, ragasztáshoz vagy csavarozáshoz.","en":"Headphone hook with a flat back for gluing or screwing.","ru":"Крючок для наушников с плоской задней частью под клей или винты."}'::jsonb, true, '', 4),
  ('clip', 'clip', 'desk', 1490, '{"hu":"Kábelrendező","en":"Cable organiser","ru":"Органайзер для кабеля"}'::jsonb, '{"hu":"Íves kábelrendező széles talppal. Az ár 1 darabra vonatkozik.","en":"Curved cable organiser with a wide base. Price is per piece.","ru":"Изогнутый органайзер для кабеля с широким основанием. Цена за 1 штуку."}'::jsonb, true, '', 5),
  ('pencup', 'pencup', 'desk', 1990, '{"hu":"Tolltartó pohár","en":"Pen cup","ru":"Стакан для ручек"}'::jsonb, '{"hu":"Tolltartó pohár az íróasztalra.","en":"Pen cup for the desk.","ru":"Стакан для ручек на рабочий стол."}'::jsonb, true, '', 6),
  ('knot', 'knot', 'play', 3490, '{"hu":"Csomó asztali figura","en":"Knot desk figure","ru":"Узел, настольная фигурка"}'::jsonb, '{"hu":"Torus-csomó, díszként az asztalra. A rétegvonalak a látványhoz tartoznak.","en":"Torus knot as a desk ornament. Layer lines are part of the look.","ru":"Тор-узел как украшение стола. Линии слоёв часть внешнего вида."}'::jsonb, true, '', 7),
  ('pawn', 'pawn', 'play', 1790, '{"hu":"Sakk-gyalog","en":"Chess pawn","ru":"Шахматная пешка"}'::jsonb, '{"hu":"Sakk-gyalog, a bástyával egy sorozatból.","en":"Chess pawn, same series as the rook.","ru":"Шахматная пешка, из одной серии с ладьёй."}'::jsonb, true, '', 8),
  ('rook', 'rook', 'play', 2190, '{"hu":"Sakk-bástya","en":"Chess rook","ru":"Шахматная ладья"}'::jsonb, '{"hu":"Sakk-bástya négy fogazattal.","en":"Chess rook with four crenels.","ru":"Шахматная ладья с четырьмя зубцами."}'::jsonb, true, '', 9),
  ('gear', 'gear', 'parts', 1250, '{"hu":"Fogaskerék","en":"Gear","ru":"Шестерня"}'::jsonb, '{"hu":"Egyenes fogazású fogaskerék, 16 fog, 8 mm-es furat.","en":"Spur gear, 16 teeth, 8 mm bore.","ru":"Прямозубая шестерня, 16 зубьев, отверстие 8 мм."}'::jsonb, true, '', 10),
  ('spool', 'spool', 'parts', 990, '{"hu":"Orsóadapter","en":"Spool adapter","ru":"Адаптер катушки"}'::jsonb, '{"hu":"Filament-orsó adapter, 20 mm-es belső furat.","en":"Filament spool adapter, 20 mm inner bore.","ru":"Адаптер для катушки филамента, внутреннее отверстие 20 мм."}'::jsonb, true, '', 11)
on conflict (id) do nothing;

insert into public.delivery (id, type, enabled, fee, name, sort) values
  ('tab', 'pickup', true, 0, '{"hu":"Személyes átvétel: Tab","en":"Pick-up: Tab","ru":"Самовывоз: Таб"}'::jsonb, 0),
  ('siofok', 'pickup', true, 0, '{"hu":"Személyes átvétel: Siófok","en":"Pick-up: Siófok","ru":"Самовывоз: Шиофок"}'::jsonb, 1),
  ('point', 'point', true, 1490, '{"hu":"Csomagpont","en":"Parcel point","ru":"Пункт выдачи"}'::jsonb, 2),
  ('home', 'home', true, 1990, '{"hu":"Házhoz szállítás","en":"Home delivery","ru":"Доставка на дом"}'::jsonb, 3)
on conflict (id) do nothing;

insert into public.coupons (code, type, value, min, expires, max_uses, used, once_per_user, active, "grant") values
  ('WELCOME10', 'percent', 10, 0, null, 0, 0, true, true, true),
  ('TAB500', 'fixed', 500, 5000, null, 0, 0, true, true, false)
on conflict (code) do nothing;

insert into public.settings (id, data) values (1, '{"leadMin":2,"leadMax":4}'::jsonb) on conflict (id) do nothing;
