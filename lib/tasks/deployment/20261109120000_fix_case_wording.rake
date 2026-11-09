# frozen_string_literal: true

# WRD-1600: wording slips in the cases — Russianisms and calques in Ukrainian («роли», «по
# запитах», «валідується проти», «модель оренди», «складний відсоток»), a «ти» in a «ви»
# sentence, slang («юзерів», «логіняться»), missing dashes, and in English a broken phrase,
# space-separated thousands, two American spellings and units glued to their numbers.
# The table is the source of truth, so the fix is made where it lives. Only the exact old phrase
# is replaced, and a metric value only when it is the whole value: a field the admin has already
# rewritten is left alone, and a second run finds nothing to change.
namespace :after_party do
  desc 'Deployment task: fix_case_wording'
  task fix_case_wording: :environment do
    replacements = {
      'Чат на 28 000 людей людина не вимодерує' =>
        'Чат на 28 000 людей не вимодерує жодна людина',
      'двічі рефінансує іпотеку між тим.' =>
        'двічі рефінансує іпотеку за цей час.',
      'з ким варто партнеритися' =>
        'з ким варто співпрацювати',
      'прибрано зі схеми — воно так і не тримало продакшн-навантаження.' =>
        'прибрано зі схеми — це рішення так і не витримало продакшн-навантаження.',
      'Один PR по пошуку' =>
        'Один PR у пошуку',
      'знак суми валідується проти типу' =>
        'знак суми перевіряється на відповідність типу',
      'новий модуль команди це новий файл' =>
        'новий модуль команди — це новий файл',
      'база при 2,1 млн юзерів' =>
        'база на 2,1 млн користувачів',
      'Продукт, у який клієнти логіняться' =>
        'Продукт, у який клієнти входять',
      'протестовані проти записаних реальних відповідей Stripe' =>
        'протестовані на записаних реальних відповідях Stripe',
      'Мертвий хост деградує фічу' =>
        'Мертвий хост погіршує роботу фічі',
      'цитату по реальних вимірах рендеру Pango, ім’я й дату по caption-рендереру' =>
        'цитату за реальними вимірами рендеру Pango, ім’я й дату за caption-рендерером',
      'вихід валідується проти білого списку' =>
        'вихід перевіряється за білим списком',
      'із платним тарифом, який реально збирає гроші' =>
        'із платним тарифом, який справді приносить гроші',
      'коли трафік усівся' =>
        'коли трафік спав',
      'бо більшість роботи це очікування' =>
        'бо більшість роботи — це очікування',
      'на CMS, яку я написав — і полігон' =>
        'на CMS, яку я написав, — і полігон',
      'переважно інтернів' =>
        'переважно стажистів',
      'апгрейди проведені живими з Rails 7.0 до 8.1' =>
        'оновлення проведені на живому сайті з Rails 7.0 до 8.1',
      'кожен перекладається' =>
        'кожна перекладається',
      'Заголовки шукаються по таблиці перекладів, а тіла — по колонках на кожну мову' =>
        'Заголовки шукаються за таблицею перекладів, а тексти — за колонками на кожну мову',
      'Коли фічі пишуть інтерни' =>
        'Коли фічі пишуть стажисти',
      'Це більша частина причини, чому головна рендериться' =>
        'Здебільшого саме тому головна рендериться',
      'Проведений живим через' =>
        'Без зупинки проведений через',
      'інженерна заявка тут' =>
        'інженерна заява тут',
      'then reworked out and dropped' =>
        'then reworked and dropped',
      '3 645 hand-written lines' =>
        '3,645 hand-written lines',
      '. 3 619 lines across' =>
        '. 3,619 lines across',
      '<b>7 919 lines</b>, of which 7 131' =>
        '<b>7,919 lines</b>, of which 7,131',
      'differently-shaped data' =>
        'differently shaped data',
      'seller-commission APIs taken <code>' =>
        'seller-commission APIs taken through <code>',
      'report access, white label, enterprise' =>
        'report access, white-label, enterprise',
      'full-stack design and implementation' =>
        'fullstack design and implementation',
      'no denormalized counter' =>
        'no denormalised counter',
      'two-level authorization' =>
        'two-level authorisation',
      'що ти існуєш.' => 'що ви існуєте.',
      '<code>connects_to</code>: роли,' => '<code>connects_to</code>: ролі,',
      'модель оренди не звели' => 'мультитенантність не звели',
      'Це складний відсоток від якості' => 'Це накопичувальний ефект якості',
      'для героя і 520×293 для картки, JPEG на 80 із вичищеними' =>
        'для головного зображення і 520×293 для картки, JPEG з якістю 80 і вичищеними',
      '53 МБ resident' => '53 МБ резидентної пам’яті',
      'resident-пам’ять' => 'резидентна пам’ять'
    }

    # A metric's value is a whole string; "7s" is replaced only where it is all there is.
    exact = {
      'en' => { '1000+' => '1,000+', '300s' => '300 s', '7s' => '7 s', '76ms' => '76 ms' },
      'uk' => { '1000+' => '1 000+' }
    }

    rewrite = lambda do |value, locale = nil|
      case value
      when String
        exact.dig(locale, value) || replacements.reduce(value) { |text, (from, to)| text.gsub(from, to) }
      when Array then value.map { |item| rewrite.call(item) }
      when Hash then value.to_h { |key, item| [key, rewrite.call(item, exact.key?(key) ? key : locale)] }
      else value
      end
    end

    # The raw JSON, not the typed attribute: what is written back is exactly what was read.
    stored = lambda do |kase, name|
      raw = kase.read_attribute_before_type_cast(name)
      raw.is_a?(String) ? JSON.parse(raw) : raw
    end

    columns = Case.columns.select { |column| column.type == :jsonb }.map(&:name)
    changed = Case.find_each.filter_map do |kase|
      updates = columns.each_with_object({}) do |name, found|
        before = stored.call(kase, name)
        after = rewrite.call(before)
        found[name] = after unless after == before
      end
      next if updates.empty?

      kase.update_columns(updates.merge(updated_at: Time.current))
      kase.slug
    end

    puts "case wording fixed in: #{changed.presence&.join(', ') || 'none'}"
    AfterParty::TaskRecord.create(version: AfterParty::TaskRecorder.new(__FILE__).timestamp)
  end
end
