// Three receipts copied from packages/receipt_parser/test/fixtures/receipts
// for the on-device parser smoke test. Regenerate by copying the files again
// if those fixtures change.

typedef ParserSample = ({
  String id,
  String input,
  bool layout,
  Map<String, String> expected,
  Map<String, String> options,
});

const parserSamples = <ParserSample>[
  (
    id: 'au_supermarket_01',
    layout: false,
    options: {
      'defaultCurrency': 'AUD',
      'dateOrder': 'dmy',
      'today': '2026-09-24',
    },
    expected: {
      'merchant': 'Woolworths Metro',
      'date': '2026-09-12',
      'total': '59.83',
      'tax': '3.02',
      'currency': 'AUD',
      'paymentMethod': 'card',
    },
    input: r'''WOOLWORTHS METRO
Woolworths Metro Surry Hills
412 Crown St, Surry Hills NSW 2010
Ph: (02) 9361 4480
ABN 41 276 953 108
TAX INVOICE

BANANAS CAVENDISH
  0.842 kg NET @ $3.90/kg           3.28
WW FULL CREAM MILK 2L               3.10
^COCA-COLA NO SUGAR 1.25L           3.65
HELGAS WHOLEMEAL BREAD 750G         5.50
^ARNOTTS TIM TAM ORIGINAL 200G
  Qty 2 @ $5.50 each               11.00
  Buy 2 Save $3.40                 -3.40
^FINISH QUANTUM TABS 40PK          27.00
  Promotional Price                -5.00
WW RSPCA CHICKEN BREAST 500G        7.50
WW FREE RANGE EGGS 12PK             7.20

9 ITEMS
TOTAL                              59.83

EFTPOS                             59.83
CHANGE                              0.00

^ Denotes item includes GST
Total includes GST                  3.02

****************************************
       YOU SAVED $8.40 TODAY
****************************************

Everyday Rewards Card        ****1937
Points earned this shop            59
Points balance                  1,284

---------- CUSTOMER COPY ----------
WOOLWORTHS METRO SURRY HILLS
MASTERCARD CREDIT
CARD NO: **** **** **** 4821
AID: A0000000041010
PURCHASE              AUD $59.83
TOTAL                 AUD $59.83
APPROVED 00       AUTH: 482915
RRN: 000419273651
-----------------------------------

12/09/2026 14:32  ST:1122 LN:04 TR:7314
Store 1122 Operator 208

  Thank you for shopping at Woolworths
Keep your receipt as proof of purchase.
Change of mind returns within 30 days.
''',
  ),
  (
    id: 'us_restaurant_01',
    layout: false,
    options: {
      'defaultCurrency': 'USD',
      'dateOrder': 'mdy',
      'today': '2026-09-24',
    },
    expected: {
      'merchant': 'Luigi\'s Trattoria',
      'date': '2026-07-18',
      'total': '139.50',
      'subtotal': '107.00',
      'tax': '9.50',
      'tip': '23.00',
      'currency': 'USD',
      'paymentMethod': 'card',
    },
    input: r'''LUIGI'S TRATTORIA
148 Mulberry Street
New York, NY 10013
(212) 555-0164

Server: 12            Table: 21
Guests: 2             Check #: 30418
07/18/26                     8:12 PM

1  Burrata                        16.00
1  Rigatoni alla Vodka            24.00
1  Chicken Parmigiana             28.00
2  Glass Chianti Classico         28.00
     @ 14.00
1  Tiramisu                       11.00

Subtotal                         107.00
Sales Tax 8.875%                   9.50
Total                            116.50

--------- MERCHANT COPY ---------
VISA            XXXXXXXXXXXX5512
Entry: CHIP     Auth Code: 071934
Trans #: 000772  Batch: 118

Suggested Gratuity:
  18% = $19.26
  20% = $21.40
  22% = $23.54

AMOUNT                      $116.50

TIP            $    23.00
             ______________

TOTAL          $   139.50
             ______________

x______________________________
      CARDHOLDER SIGNATURE
I agree to pay the above total amount
according to my card issuer agreement.

     Grazie! Buona serata!
''',
  ),
  (
    id: 'de_supermarket_01',
    layout: true,
    options: {
      'defaultCurrency': 'EUR',
      'dateOrder': 'dmy',
      'today': '2026-09-24',
    },
    expected: {
      'merchant': 'REWE',
      'date': '2026-08-15',
      'total': '24.13',
      'tax': '1.94',
      'currency': 'EUR',
      'paymentMethod': 'cash',
    },
    input: r'''{
  "engineId": "mlkit-latin",
  "imageWidth": 1000,
  "imageHeight": 2000,
  "lines": [
    {"text": "REWE", "box": {"left": 390, "top": 50, "right": 610, "bottom": 150}},
    {"text": "REWE Markt GmbH", "box": {"left": 330, "top": 175, "right": 670, "bottom": 215}},
    {"text": "Aachener Str. 118", "box": {"left": 340, "top": 230, "right": 660, "bottom": 270}},
    {"text": "50674 Köln", "box": {"left": 400, "top": 285, "right": 600, "bottom": 325}},
    {"text": "Tel.: 0221 5554 2210", "box": {"left": 320, "top": 340, "right": 680, "bottom": 380}},
    {"text": "UID Nr.: DE284719336", "box": {"left": 310, "top": 395, "right": 690, "bottom": 435}},

    {"text": "BANANEN", "box": {"left": 60, "top": 530, "right": 260, "bottom": 570}},
    {"text": "1,254 kg x 1,59 EUR/kg", "box": {"left": 100, "top": 585, "right": 520, "bottom": 625}},
    {"text": "VOLLMILCH 3,5% 1L", "box": {"left": 60, "top": 640, "right": 420, "bottom": 680}},
    {"text": "LAUGENBREZEL", "box": {"left": 60, "top": 695, "right": 330, "bottom": 735}},
    {"text": "2 Stk x 1,29", "box": {"left": 100, "top": 750, "right": 360, "bottom": 790}},
    {"text": "GOUDA JUNG SCHEIBEN", "box": {"left": 60, "top": 805, "right": 440, "bottom": 845}},
    {"text": "COCA-COLA 1,5L", "box": {"left": 60, "top": 860, "right": 340, "bottom": 900}},
    {"text": "PFAND 0,25 EUR", "box": {"left": 60, "top": 915, "right": 340, "bottom": 955}},
    {"text": "PRIL SPUELMITTEL", "box": {"left": 60, "top": 970, "right": 380, "bottom": 1010}},
    {"text": "KAFFEE CREMA 1KG", "box": {"left": 60, "top": 1025, "right": 380, "bottom": 1065}},
    {"text": "RABATT KAFFEE", "box": {"left": 100, "top": 1080, "right": 380, "bottom": 1120}},
    {"text": "SUMME", "box": {"left": 60, "top": 1150, "right": 260, "bottom": 1240}},
    {"text": "Geg. BAR", "box": {"left": 60, "top": 1265, "right": 240, "bottom": 1305}},
    {"text": "Rückgeld BAR", "box": {"left": 60, "top": 1320, "right": 300, "bottom": 1360}},

    {"text": "EUR", "box": {"left": 860, "top": 470, "right": 940, "bottom": 510}},
    {"text": "1,99 B", "box": {"left": 790, "top": 530, "right": 940, "bottom": 570}},
    {"text": "1,19 B", "box": {"left": 790, "top": 640, "right": 940, "bottom": 680}},
    {"text": "2,58 B", "box": {"left": 790, "top": 695, "right": 940, "bottom": 735}},
    {"text": "2,49 B", "box": {"left": 790, "top": 805, "right": 940, "bottom": 845}},
    {"text": "1,69 A", "box": {"left": 790, "top": 860, "right": 940, "bottom": 900}},
    {"text": "0,25 A", "box": {"left": 790, "top": 915, "right": 940, "bottom": 955}},
    {"text": "1,95 A", "box": {"left": 790, "top": 970, "right": 940, "bottom": 1010}},
    {"text": "13,99 B", "box": {"left": 770, "top": 1025, "right": 940, "bottom": 1065}},
    {"text": "-2,00 B", "box": {"left": 770, "top": 1080, "right": 940, "bottom": 1120}},
    {"text": "24,13", "box": {"left": 740, "top": 1150, "right": 940, "bottom": 1240}},
    {"text": "30,00", "box": {"left": 800, "top": 1265, "right": 940, "bottom": 1305}},
    {"text": "5,87", "box": {"left": 820, "top": 1320, "right": 940, "bottom": 1360}},

    {"text": "Steuer %   Netto   Steuer   Brutto", "box": {"left": 60, "top": 1400, "right": 940, "bottom": 1440}},
    {"text": "A= 19,0%    3,27     0,62     3,89", "box": {"left": 60, "top": 1455, "right": 940, "bottom": 1495}},
    {"text": "B=  7,0%   18,92     1,32    20,24", "box": {"left": 60, "top": 1510, "right": 940, "bottom": 1550}},
    {"text": "Gesamtbetrag  22,19   1,94    24,13", "box": {"left": 60, "top": 1565, "right": 940, "bottom": 1605}},
    {"text": "15.08.2026 11:34  Bon-Nr.:4471", "box": {"left": 60, "top": 1660, "right": 700, "bottom": 1700}},
    {"text": "Markt:5021  Kasse:3  Bed.:302302", "box": {"left": 60, "top": 1715, "right": 700, "bottom": 1755}},
    {"text": "REWE Bonus-Guthaben: 3,42 EUR", "box": {"left": 60, "top": 1790, "right": 640, "bottom": 1830}},
    {"text": "Vielen Dank für Ihren Einkauf", "box": {"left": 220, "top": 1870, "right": 780, "bottom": 1910}}
  ]
}
''',
  ),
];
