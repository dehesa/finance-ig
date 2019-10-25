import Foundation

/// List of all supported countries.
public enum Country: Hashable, CaseIterable, Decodable {
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
    
    private static let matcher: [Country:CountryType.Type] = [
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
        guard let result = Self.matcher.first(where: { $0.value.alphaCode2 == alphaCode2 }) else { return nil }
        self = result.key
    }
    
    /// Initialize a country from its three-letter ISO 3166 code.
    public init?(alphaCode3: String) {
        guard let result = Self.matcher.first(where: { $0.value.alphaCode3 == alphaCode3 }) else { return nil }
        self = result.key
    }
    
    /// Initialize a country from its numeric ISO 3166 code.
    public init?(numeric: Int) {
        guard let result = Self.matcher.first(where: { $0.value.numeric == numeric }) else { return nil }
        self = result.key
    }
    
    public init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let closure: ((key: Country, value: CountryType.Type)) -> Bool
        
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
        
        guard let result = Self.matcher.first(where: closure) else {
            throw DecodingError.dataCorruptedError(in: container, debugDescription: "The decoded value is not supported.")
        }
        
        self = result.key
    }
    
    private var underlyingType: CountryType.Type {
        Self.matcher[self]!
    }
    
    /// The human readable name of the receiving country.
    public var name: String { self.underlyingType.name }
    /// The two letter ISO 3166 code.
    public var alphaCode2: String { self.underlyingType.alphaCode2 }
    /// The three letter ISO 3166 code.
    public var alphaCode3: String { self.underlyingType.alphaCode3 }
    /// The numeric ISO 3166 code.
    public var numeric: Int { self.underlyingType.numeric }
}

// MARK: -

/// Base for all countries.
private protocol CountryType {
    /// The human readable name of the receiving country.
    static var name: String { get }
    /// The two letter ISO 3166 code.
    static var alphaCode2: String { get }
    /// The three letter ISO 3166 code.
    static var alphaCode3: String { get }
    /// The numeric ISO 3166 code.
    static var numeric: Int { get }
}

extension IG.Country {
    /// Canada.
    private struct Canada: CountryType {
        static var name: String { "Canada" }
        static var alphaCode2: String { "CA" }
        static var alphaCode3: String { "CAN" }
        static var numeric: Int { 124 }
    }
    
    /// United States of America.
    private struct UnitedStates: CountryType {
        static var name: String { "United States" }
        static var alphaCode2: String { "US" }
        static var alphaCode3: String { "USA" }
        static var numeric: Int { 840 }
    }
    
    /// México.
    private struct Mexico: CountryType {
        static var name: String { "Mexico" }
        static var alphaCode2: String { "MX" }
        static var alphaCode3: String { "MEX" }
        static var numeric: Int { 484 }
    }
    
    /// Colombia.
    private struct Colombia: CountryType {
        static var name: String { "Colombia" }
        static var alphaCode2: String { "CO" }
        static var alphaCode3: String { "COL" }
        static var numeric: Int { 170 }
    }
    
    /// Peru.
    private struct Peru: CountryType {
        static var name: String { "Peru" }
        static var alphaCode2: String { "PE" }
        static var alphaCode3: String { "PER" }
        static var numeric: Int { 604 }
    }
    
    /// Chile.
    private struct Chile: CountryType {
        static var name: String { "Chile" }
        static var alphaCode2: String { "CL" }
        static var alphaCode3: String { "CHL" }
        static var numeric: Int { 152 }
    }
    
    /// Brazil.
    private struct Brazil: CountryType {
        static var name: String { "Brazil" }
        static var alphaCode2: String { "BR" }
        static var alphaCode3: String { "BRA" }
        static var numeric: Int { 76 }
    }
    
    /// Argentina.
    private struct Argentina: CountryType {
        static var name: String { "Argentina" }
        static var alphaCode2: String { "AR" }
        static var alphaCode3: String { "ARG" }
        static var numeric: Int { 32 }
    }
    
    /// Iceland.
    private struct Iceland: CountryType {
        static var name: String { "Iceland" }
        static var alphaCode2: String { "IS" }
        static var alphaCode3: String { "ISL" }
        static var numeric: Int { 352 }
    }
    
    /// Republic of Ireland.
    private struct Ireland: CountryType {
        static var name: String { "Ireland" }
        static var alphaCode2: String { "IE" }
        static var alphaCode3: String { "IRL" }
        static var numeric: Int { 372 }
    }
    
    /// United Kingdom of Great Britain and Northern Ireland.
    private struct UnitedKingdom: CountryType {
        static var name: String { "United Kingdom" }
        static var alphaCode2: String { "GB" }
        static var alphaCode3: String { "GBR" }
        static var numeric: Int { 826 }
    }
    
    /// Norway.
    private struct Norway: CountryType {
        static var name: String { "Norway" }
        static var alphaCode2: String { "NO" }
        static var alphaCode3: String { "NOR" }
        static var numeric: Int { 578 }
    }
    
    /// Sweden.
    private struct Sweden: CountryType {
        static var name: String { "Sweden" }
        static var alphaCode2: String { "SE" }
        static var alphaCode3: String { "SWE" }
        static var numeric: Int { 752 }
    }
    
    /// Denmark.
    private struct Denmark: CountryType {
        static var name: String { "Denmark" }
        static var alphaCode2: String { "DK" }
        static var alphaCode3: String { "DNK" }
        static var numeric: Int { 208 }
    }
    
    /// Finland.
    private struct Finland: CountryType {
        static var name: String { "Finland" }
        static var alphaCode2: String { "FI" }
        static var alphaCode3: String { "FIN" }
        static var numeric: Int { 246 }
    }
    
    /// Portugal.
    private struct Portugal: CountryType {
        static var name: String { "Portugal" }
        static var alphaCode2: String { "PT" }
        static var alphaCode3: String { "PRT" }
        static var numeric: Int { 620 }
    }
    
    /// Spain
    private struct Spain: CountryType {
        static var name: String { "Spain" }
        static var alphaCode2: String { "ES" }
        static var alphaCode3: String { "ESP" }
        static var numeric: Int { 724 }
    }
    
    /// France.
    private struct France: CountryType {
        static var name: String { "France" }
        static var alphaCode2: String { "FR" }
        static var alphaCode3: String { "FRA" }
        static var numeric: Int { 250 }
    }
    
    /// Belgium.
    private struct Belgium: CountryType {
        static var name: String { "Belgium" }
        static var alphaCode2: String { "BE" }
        static var alphaCode3: String { "BEL" }
        static var numeric: Int { 56 }
    }
    
    /// The Netherlands.
    private struct Netherlands: CountryType {
        static var name: String { "Netherlands" }
        static var alphaCode2: String { "NL" }
        static var alphaCode3: String { "NLD" }
        static var numeric: Int { 528 }
    }
    
    /// European Union.
    /// - attention: The European Union is no in the ISO 3166, that is why the 3 letter code and the numeric code are not really "true".
    private struct EuropeanUnion: CountryType {
        static var name: String { "European Union" }
        static var alphaCode2: String { "EU" }
        static var alphaCode3: String { "EUR" }
        static var numeric: Int { 0 }
    }
    
    /// Switzerland
    private struct Switzerland: CountryType {
        static var name: String { "Switzerland" }
        static var alphaCode2: String { "CH" }
        static var alphaCode3: String { "CHE" }
        static var numeric: Int { 756 }
    }
    
    /// Italy
    private struct Italy: CountryType {
        static var name: String { "Italy" }
        static var alphaCode2: String { "IT" }
        static var alphaCode3: String { "ITA" }
        static var numeric: Int { 380 }
    }
    
    /// Slovenia..
    private struct Slovenia: CountryType {
        static var name: String { "Slovenia" }
        static var alphaCode2: String { "SI" }
        static var alphaCode3: String { "SVN" }
        static var numeric: Int { 705 }
    }
    
    /// Croatia.
    private struct Croatia: CountryType {
        static var name: String { "Croatia" }
        static var alphaCode2: String { "HR" }
        static var alphaCode3: String { "HRV" }
        static var numeric: Int { 191 }
    }
    
    /// Germany
    private struct Germany: CountryType {
        static var name: String { "Germany" }
        static var alphaCode2: String { "DE" }
        static var alphaCode3: String { "DEU" }
        static var numeric: Int { 276 }
    }
    
    /// Austria
    private struct Austria: CountryType {
        static var name: String { "Austria" }
        static var alphaCode2: String { "AT" }
        static var alphaCode3: String { "AUT" }
        static var numeric: Int { 40 }
    }
    
    /// Czech Republic.
    private struct Czechia: CountryType {
        static var name: String { "Czechia" }
        static var alphaCode2: String { "CZ" }
        static var alphaCode3: String { "CZE" }
        static var numeric: Int { 203 }
    }
    
    /// Hungary.
    private struct Hungary: CountryType {
        static var name: String { "Hungary" }
        static var alphaCode2: String { "HU" }
        static var alphaCode3: String { "HUN" }
        static var numeric: Int { 348 }
    }
    
    /// Slovakia.
    private struct Slovakia: CountryType {
        static var name: String { "Slovakia" }
        static var alphaCode2: String { "SK" }
        static var alphaCode3: String { "SVK" }
        static var numeric: Int { 703 }
    }
    
    /// Romania.
    private struct Romania: CountryType {
        static var name: String { "Romania" }
        static var alphaCode2: String { "RO" }
        static var alphaCode3: String { "ROU" }
        static var numeric: Int { 642 }
    }
    
    /// Bulgaria.
    private struct Bulgaria: CountryType {
        static var name: String { "Bulgaria" }
        static var alphaCode2: String { "BG" }
        static var alphaCode3: String { "BGR" }
        static var numeric: Int { 100 }
    }
    
    /// Poland.
    private struct Poland: CountryType {
        static var name: String { "Poland" }
        static var alphaCode2: String { "PL" }
        static var alphaCode3: String { "POL" }
        static var numeric: Int { 616 }
    }
    
    /// Estonia
    private struct Estonia: CountryType {
        static var name: String { "Estonia" }
        static var alphaCode2: String { "EE" }
        static var alphaCode3: String { "EST" }
        static var numeric: Int { 233 }
    }
    
    /// Latvia.
    private struct Latvia: CountryType {
        static var name: String { "Latvia" }
        static var alphaCode2: String { "LV" }
        static var alphaCode3: String { "LVA" }
        static var numeric: Int { 428 }
    }
    
    /// Lithuania.
    private struct Lithuania: CountryType {
        static var name: String { "Lithuania" }
        static var alphaCode2: String { "LT" }
        static var alphaCode3: String { "LTU" }
        static var numeric: Int { 440 }
    }
    
    /// Ukrania.
    private struct Ukraine: CountryType {
        static var name: String { "Ukraine" }
        static var alphaCode2: String { "UA" }
        static var alphaCode3: String { "UKR" }
        static var numeric: Int { 804 }
    }
    
    /// Russian Federation.
    private struct Russia: CountryType {
        static var name: String { "Russia" }
        static var alphaCode2: String { "RU" }
        static var alphaCode3: String { "RUS" }
        static var numeric: Int { 643 }
    }
    
    /// Greece
    private struct Greece: CountryType {
        static var name: String { "Greece" }
        static var alphaCode2: String { "GR" }
        static var alphaCode3: String { "GRC" }
        static var numeric: Int { 300 }
    }
    
    /// Turkey.
    private struct Turkey: CountryType {
        static var name: String { "Turkey" }
        static var alphaCode2: String { "TR" }
        static var alphaCode3: String { "TUR" }
        static var numeric: Int { 792 }
    }
    
    /// South Africa.
    private struct SouthAfrica: CountryType {
        static var name: String { "South Africa" }
        static var alphaCode2: String { "ZA" }
        static var alphaCode3: String { "ZAF" }
        static var numeric: Int { 710 }
    }
    
    /// India.
    private struct India: CountryType {
        static var name: String { "India" }
        static var alphaCode2: String { "IN" }
        static var alphaCode3: String { "IND" }
        static var numeric: Int { 356 }
    }
    
    /// Singapore.
    private struct Singapore: CountryType {
        static var name: String { "Singapore" }
        static var alphaCode2: String { "SG" }
        static var alphaCode3: String { "SGP" }
        static var numeric: Int { 702 }
    }
    
    /// Republic of China.
    private struct China: CountryType {
        static var name: String { "China" }
        static var alphaCode2: String { "CN" }
        static var alphaCode3: String { "CHN" }
        static var numeric: Int { 156 }
    }
    
    /// Hong Kong.
    private struct HongKong: CountryType {
        static var name: String { "Hong Kong" }
        static var alphaCode2: String { "HK" }
        static var alphaCode3: String { "HKG" }
        static var numeric: Int { 344 }
    }
    
    /// Taiwan.
    private struct Taiwan: CountryType {
        static var name: String { "Taiwan" }
        static var alphaCode2: String { "TW" }
        static var alphaCode3: String { "TWN" }
        static var numeric: Int { 158 }
    }
    
    /// Republic of Korea.
    private struct SouthKorea: CountryType {
        static var name: String { "South Korea" }
        static var alphaCode2: String { "KR" }
        static var alphaCode3: String { "KOR" }
        static var numeric: Int { 410 }
    }
    
    /// Japan.
    private struct Japan: CountryType {
        static var name: String { "Japan" }
        static var alphaCode2: String { "JP" }
        static var alphaCode3: String { "JPN" }
        static var numeric: Int { 392 }
    }
    
    /// The Philippines.
    private struct Philippines: CountryType {
        static var name: String { "The Philippines" }
        static var alphaCode2: String { "PH" }
        static var alphaCode3: String { "PHL" }
        static var numeric: Int { 608 }
    }
    
    /// Indonesia.
    private struct Indonesia: CountryType {
        static var name: String { "Indonesia" }
        static var alphaCode2: String { "ID" }
        static var alphaCode3: String { "IDN" }
        static var numeric: Int { 360 }
    }
    
    /// Australia.
    private struct Australia: CountryType {
        static var name: String { "Australia" }
        static var alphaCode2: String { "AU" }
        static var alphaCode3: String { "AUS" }
        static var numeric: Int { 36 }
    }
    
    /// New Zealand.
    private struct NewZealand: CountryType {
        static var name: String { "New Zealand" }
        static var alphaCode2: String { "NZ" }
        static var alphaCode3: String { "NZL" }
        static var numeric: Int { 554 }
    }
}
