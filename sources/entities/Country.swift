/// List of all supported countries.
public enum Country: Hashable, CaseIterable {
    case canada
    case unitedStates
    case mexico
    case colombia
    case peru
    case chile
    case brazil
    case argentina
    case iceland
    case ireland
    case unitedKingdom
    case norway
    case sweden
    case denmark
    case finland
    case portugal
    case spain
    case france
    case belgium
    case netherlands
    case europeanUnion
    case switzerland
    case italy
    case slovenia
    case croatia
    case germany
    case austria
    case czechia
    case hungary
    case slovakia
    case romania
    case bulgaria
    case poland
    case estonia
    case latvia
    case lithuania
    case ukraine
    case russia
    case greece
    case turkey
    case southAfrica
    case india
    case singapore
    case china
    case hongKong
    case taiwan
    case southKorea
    case japan
    case philippines
    case indonesia
    case australia
    case newZealand
    
    private static let _matcher: [Country:_CountryType.Type] = [
        .canada: Country.Canada.self,
        .unitedStates: Country.UnitedStates.self,
        .mexico: Country.Mexico.self,
        .colombia: Country.Colombia.self,
        .peru: Country.Peru.self,
        .chile: Country.Chile.self,
        .brazil: Country.Brazil.self,
        .argentina: Country.Argentina.self,
        .iceland: Country.Iceland.self,
        .ireland: Country.Ireland.self,
        .unitedKingdom: Country.UnitedKingdom.self,
        .norway: Country.Norway.self,
        .sweden: Country.Sweden.self,
        .denmark: Country.Denmark.self,
        .finland: Country.Finland.self,
        .portugal: Country.Portugal.self,
        .spain: Country.Spain.self,
        .france: Country.France.self,
        .belgium: Country.Belgium.self,
        .netherlands: Country.Netherlands.self,
        .europeanUnion: Country.EuropeanUnion.self,
        .switzerland: Country.Switzerland.self,
        .italy: Country.Italy.self,
        .slovenia: Country.Slovenia.self,
        .croatia: Country.Croatia.self,
        .germany: Country.Germany.self,
        .austria: Country.Austria.self,
        .czechia: Country.Czechia.self,
        .hungary: Country.Hungary.self,
        .slovakia: Country.Slovakia.self,
        .romania: Country.Romania.self,
        .bulgaria: Country.Bulgaria.self,
        .poland: Country.Poland.self,
        .estonia: Country.Estonia.self,
        .latvia: Country.Latvia.self,
        .lithuania: Country.Lithuania.self,
        .ukraine: Country.Ukraine.self,
        .russia: Country.Russia.self,
        .greece: Country.Greece.self,
        .turkey: Country.Turkey.self,
        .southAfrica: Country.SouthAfrica.self,
        .india: Country.India.self,
        .singapore: Country.Singapore.self,
        .china: Country.China.self,
        .hongKong: Country.HongKong.self,
        .taiwan: Country.Taiwan.self,
        .southKorea: Country.SouthKorea.self,
        .japan: Country.Japan.self,
        .philippines: Country.Philippines.self,
        .indonesia: Country.Indonesia.self,
        .australia: Country.Australia.self,
        .newZealand: Country.NewZealand.self,
    ]
    
    /// Initialize a country from its two-letter ISO 3166 code.
    public init?(alphaCode2: String) {
        guard let result = Self._matcher.first(where: { $0.value.alphaCode2 == alphaCode2 }) else { return nil }
        self = result.key
    }
    
    /// Initialize a country from its three-letter ISO 3166 code.
    public init?(alphaCode3: String) {
        guard let result = Self._matcher.first(where: { $0.value.alphaCode3 == alphaCode3 }) else { return nil }
        self = result.key
    }
    
    /// Initialize a country from its numeric ISO 3166 code.
    public init?(numeric: Int) {
        guard let result = Self._matcher.first(where: { $0.value.numeric == numeric }) else { return nil }
        self = result.key
    }
    
    /// The human readable name of the receiving country.
    public var name: String { self._underlyingType.name }
    /// The two letter ISO 3166 code.
    public var alphaCode2: String { self._underlyingType.alphaCode2 }
    /// The three letter ISO 3166 code.
    public var alphaCode3: String { self._underlyingType.alphaCode3 }
    /// The numeric ISO 3166 code.
    public var numeric: Int { self._underlyingType.numeric }
}

// MARK: -

/// Base for all countries.
private protocol _CountryType {
    /// The human readable name of the receiving country.
    static var name: String { get }
    /// The two letter ISO 3166 code.
    static var alphaCode2: String { get }
    /// The three letter ISO 3166 code.
    static var alphaCode3: String { get }
    /// The numeric ISO 3166 code.
    static var numeric: Int { get }
}

extension Country {
    /// Canada.
    private struct Canada: _CountryType {
        static var name: String { "Canada" }
        static var alphaCode2: String { "CA" }
        static var alphaCode3: String { "CAN" }
        static var numeric: Int { 124 }
    }
    
    /// United States of America.
    private struct UnitedStates: _CountryType {
        static var name: String { "United States" }
        static var alphaCode2: String { "US" }
        static var alphaCode3: String { "USA" }
        static var numeric: Int { 840 }
    }
    
    /// México.
    private struct Mexico: _CountryType {
        static var name: String { "Mexico" }
        static var alphaCode2: String { "MX" }
        static var alphaCode3: String { "MEX" }
        static var numeric: Int { 484 }
    }
    
    /// Colombia.
    private struct Colombia: _CountryType {
        static var name: String { "Colombia" }
        static var alphaCode2: String { "CO" }
        static var alphaCode3: String { "COL" }
        static var numeric: Int { 170 }
    }
    
    /// Peru.
    private struct Peru: _CountryType {
        static var name: String { "Peru" }
        static var alphaCode2: String { "PE" }
        static var alphaCode3: String { "PER" }
        static var numeric: Int { 604 }
    }
    
    /// Chile.
    private struct Chile: _CountryType {
        static var name: String { "Chile" }
        static var alphaCode2: String { "CL" }
        static var alphaCode3: String { "CHL" }
        static var numeric: Int { 152 }
    }
    
    /// Brazil.
    private struct Brazil: _CountryType {
        static var name: String { "Brazil" }
        static var alphaCode2: String { "BR" }
        static var alphaCode3: String { "BRA" }
        static var numeric: Int { 76 }
    }
    
    /// Argentina.
    private struct Argentina: _CountryType {
        static var name: String { "Argentina" }
        static var alphaCode2: String { "AR" }
        static var alphaCode3: String { "ARG" }
        static var numeric: Int { 32 }
    }
    
    /// Iceland.
    private struct Iceland: _CountryType {
        static var name: String { "Iceland" }
        static var alphaCode2: String { "IS" }
        static var alphaCode3: String { "ISL" }
        static var numeric: Int { 352 }
    }
    
    /// Republic of Ireland.
    private struct Ireland: _CountryType {
        static var name: String { "Ireland" }
        static var alphaCode2: String { "IE" }
        static var alphaCode3: String { "IRL" }
        static var numeric: Int { 372 }
    }
    
    /// United Kingdom of Great Britain and Northern Ireland.
    private struct UnitedKingdom: _CountryType {
        static var name: String { "United Kingdom" }
        static var alphaCode2: String { "GB" }
        static var alphaCode3: String { "GBR" }
        static var numeric: Int { 826 }
    }
    
    /// Norway.
    private struct Norway: _CountryType {
        static var name: String { "Norway" }
        static var alphaCode2: String { "NO" }
        static var alphaCode3: String { "NOR" }
        static var numeric: Int { 578 }
    }
    
    /// Sweden.
    private struct Sweden: _CountryType {
        static var name: String { "Sweden" }
        static var alphaCode2: String { "SE" }
        static var alphaCode3: String { "SWE" }
        static var numeric: Int { 752 }
    }
    
    /// Denmark.
    private struct Denmark: _CountryType {
        static var name: String { "Denmark" }
        static var alphaCode2: String { "DK" }
        static var alphaCode3: String { "DNK" }
        static var numeric: Int { 208 }
    }
    
    /// Finland.
    private struct Finland: _CountryType {
        static var name: String { "Finland" }
        static var alphaCode2: String { "FI" }
        static var alphaCode3: String { "FIN" }
        static var numeric: Int { 246 }
    }
    
    /// Portugal.
    private struct Portugal: _CountryType {
        static var name: String { "Portugal" }
        static var alphaCode2: String { "PT" }
        static var alphaCode3: String { "PRT" }
        static var numeric: Int { 620 }
    }
    
    /// Spain
    private struct Spain: _CountryType {
        static var name: String { "Spain" }
        static var alphaCode2: String { "ES" }
        static var alphaCode3: String { "ESP" }
        static var numeric: Int { 724 }
    }
    
    /// France.
    private struct France: _CountryType {
        static var name: String { "France" }
        static var alphaCode2: String { "FR" }
        static var alphaCode3: String { "FRA" }
        static var numeric: Int { 250 }
    }
    
    /// Belgium.
    private struct Belgium: _CountryType {
        static var name: String { "Belgium" }
        static var alphaCode2: String { "BE" }
        static var alphaCode3: String { "BEL" }
        static var numeric: Int { 56 }
    }
    
    /// The Netherlands.
    private struct Netherlands: _CountryType {
        static var name: String { "Netherlands" }
        static var alphaCode2: String { "NL" }
        static var alphaCode3: String { "NLD" }
        static var numeric: Int { 528 }
    }
    
    /// European Union.
    /// - attention: The European Union is no in the ISO 3166, that is why the 3 letter code and the numeric code are not really "true".
    private struct EuropeanUnion: _CountryType {
        static var name: String { "European Union" }
        static var alphaCode2: String { "EU" }
        static var alphaCode3: String { "EUR" }
        static var numeric: Int { 0 }
    }
    
    /// Switzerland
    private struct Switzerland: _CountryType {
        static var name: String { "Switzerland" }
        static var alphaCode2: String { "CH" }
        static var alphaCode3: String { "CHE" }
        static var numeric: Int { 756 }
    }
    
    /// Italy
    private struct Italy: _CountryType {
        static var name: String { "Italy" }
        static var alphaCode2: String { "IT" }
        static var alphaCode3: String { "ITA" }
        static var numeric: Int { 380 }
    }
    
    /// Slovenia..
    private struct Slovenia: _CountryType {
        static var name: String { "Slovenia" }
        static var alphaCode2: String { "SI" }
        static var alphaCode3: String { "SVN" }
        static var numeric: Int { 705 }
    }
    
    /// Croatia.
    private struct Croatia: _CountryType {
        static var name: String { "Croatia" }
        static var alphaCode2: String { "HR" }
        static var alphaCode3: String { "HRV" }
        static var numeric: Int { 191 }
    }
    
    /// Germany
    private struct Germany: _CountryType {
        static var name: String { "Germany" }
        static var alphaCode2: String { "DE" }
        static var alphaCode3: String { "DEU" }
        static var numeric: Int { 276 }
    }
    
    /// Austria
    private struct Austria: _CountryType {
        static var name: String { "Austria" }
        static var alphaCode2: String { "AT" }
        static var alphaCode3: String { "AUT" }
        static var numeric: Int { 40 }
    }
    
    /// Czech Republic.
    private struct Czechia: _CountryType {
        static var name: String { "Czechia" }
        static var alphaCode2: String { "CZ" }
        static var alphaCode3: String { "CZE" }
        static var numeric: Int { 203 }
    }
    
    /// Hungary.
    private struct Hungary: _CountryType {
        static var name: String { "Hungary" }
        static var alphaCode2: String { "HU" }
        static var alphaCode3: String { "HUN" }
        static var numeric: Int { 348 }
    }
    
    /// Slovakia.
    private struct Slovakia: _CountryType {
        static var name: String { "Slovakia" }
        static var alphaCode2: String { "SK" }
        static var alphaCode3: String { "SVK" }
        static var numeric: Int { 703 }
    }
    
    /// Romania.
    private struct Romania: _CountryType {
        static var name: String { "Romania" }
        static var alphaCode2: String { "RO" }
        static var alphaCode3: String { "ROU" }
        static var numeric: Int { 642 }
    }
    
    /// Bulgaria.
    private struct Bulgaria: _CountryType {
        static var name: String { "Bulgaria" }
        static var alphaCode2: String { "BG" }
        static var alphaCode3: String { "BGR" }
        static var numeric: Int { 100 }
    }
    
    /// Poland.
    private struct Poland: _CountryType {
        static var name: String { "Poland" }
        static var alphaCode2: String { "PL" }
        static var alphaCode3: String { "POL" }
        static var numeric: Int { 616 }
    }
    
    /// Estonia
    private struct Estonia: _CountryType {
        static var name: String { "Estonia" }
        static var alphaCode2: String { "EE" }
        static var alphaCode3: String { "EST" }
        static var numeric: Int { 233 }
    }
    
    /// Latvia.
    private struct Latvia: _CountryType {
        static var name: String { "Latvia" }
        static var alphaCode2: String { "LV" }
        static var alphaCode3: String { "LVA" }
        static var numeric: Int { 428 }
    }
    
    /// Lithuania.
    private struct Lithuania: _CountryType {
        static var name: String { "Lithuania" }
        static var alphaCode2: String { "LT" }
        static var alphaCode3: String { "LTU" }
        static var numeric: Int { 440 }
    }
    
    /// Ukrania.
    private struct Ukraine: _CountryType {
        static var name: String { "Ukraine" }
        static var alphaCode2: String { "UA" }
        static var alphaCode3: String { "UKR" }
        static var numeric: Int { 804 }
    }
    
    /// Russian Federation.
    private struct Russia: _CountryType {
        static var name: String { "Russia" }
        static var alphaCode2: String { "RU" }
        static var alphaCode3: String { "RUS" }
        static var numeric: Int { 643 }
    }
    
    /// Greece
    private struct Greece: _CountryType {
        static var name: String { "Greece" }
        static var alphaCode2: String { "GR" }
        static var alphaCode3: String { "GRC" }
        static var numeric: Int { 300 }
    }
    
    /// Turkey.
    private struct Turkey: _CountryType {
        static var name: String { "Turkey" }
        static var alphaCode2: String { "TR" }
        static var alphaCode3: String { "TUR" }
        static var numeric: Int { 792 }
    }
    
    /// South Africa.
    private struct SouthAfrica: _CountryType {
        static var name: String { "South Africa" }
        static var alphaCode2: String { "ZA" }
        static var alphaCode3: String { "ZAF" }
        static var numeric: Int { 710 }
    }
    
    /// India.
    private struct India: _CountryType {
        static var name: String { "India" }
        static var alphaCode2: String { "IN" }
        static var alphaCode3: String { "IND" }
        static var numeric: Int { 356 }
    }
    
    /// Singapore.
    private struct Singapore: _CountryType {
        static var name: String { "Singapore" }
        static var alphaCode2: String { "SG" }
        static var alphaCode3: String { "SGP" }
        static var numeric: Int { 702 }
    }
    
    /// Republic of China.
    private struct China: _CountryType {
        static var name: String { "China" }
        static var alphaCode2: String { "CN" }
        static var alphaCode3: String { "CHN" }
        static var numeric: Int { 156 }
    }
    
    /// Hong Kong.
    private struct HongKong: _CountryType {
        static var name: String { "Hong Kong" }
        static var alphaCode2: String { "HK" }
        static var alphaCode3: String { "HKG" }
        static var numeric: Int { 344 }
    }
    
    /// Taiwan.
    private struct Taiwan: _CountryType {
        static var name: String { "Taiwan" }
        static var alphaCode2: String { "TW" }
        static var alphaCode3: String { "TWN" }
        static var numeric: Int { 158 }
    }
    
    /// Republic of Korea.
    private struct SouthKorea: _CountryType {
        static var name: String { "South Korea" }
        static var alphaCode2: String { "KR" }
        static var alphaCode3: String { "KOR" }
        static var numeric: Int { 410 }
    }
    
    /// Japan.
    private struct Japan: _CountryType {
        static var name: String { "Japan" }
        static var alphaCode2: String { "JP" }
        static var alphaCode3: String { "JPN" }
        static var numeric: Int { 392 }
    }
    
    /// The Philippines.
    private struct Philippines: _CountryType {
        static var name: String { "The Philippines" }
        static var alphaCode2: String { "PH" }
        static var alphaCode3: String { "PHL" }
        static var numeric: Int { 608 }
    }
    
    /// Indonesia.
    private struct Indonesia: _CountryType {
        static var name: String { "Indonesia" }
        static var alphaCode2: String { "ID" }
        static var alphaCode3: String { "IDN" }
        static var numeric: Int { 360 }
    }
    
    /// Australia.
    private struct Australia: _CountryType {
        static var name: String { "Australia" }
        static var alphaCode2: String { "AU" }
        static var alphaCode3: String { "AUS" }
        static var numeric: Int { 36 }
    }
    
    /// New Zealand.
    private struct NewZealand: _CountryType {
        static var name: String { "New Zealand" }
        static var alphaCode2: String { "NZ" }
        static var alphaCode3: String { "NZL" }
        static var numeric: Int { 554 }
    }
}

// MARK: -

extension Country: Decodable {
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let closure: ((key: Country, value: _CountryType.Type)) -> Bool
        
        if let string = try? container.decode(String.self) {
            switch string.count {
            case 0: throw DecodingError.dataCorruptedError(in: container, debugDescription: "A country cannot be represented by an empty String")
            case 2: closure = { $0.value.alphaCode2 == string }
            case 3: closure = { $0.value.alphaCode3 == string }
            default: closure = { $0.value.name == string }
            }
        } else if let number = try? container.decode(Int.self) {
            closure = { $0.value.numeric == number }
        } else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The country value is not a String or an Integer")
        }
        
        guard let result = Self._matcher.first(where: closure) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The decoded value is not supported.")
        }
        
        self = result.key
    }
    
    private var _underlyingType: _CountryType.Type {
        Self._matcher[self].unsafelyUnwrapped
    }
}
