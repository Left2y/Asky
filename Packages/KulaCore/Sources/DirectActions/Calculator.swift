import Foundation

/// Restricted arithmetic parser. Never evaluates code: only numbers, + - * / % ^, parentheses.
public enum Calculator {
    public enum CalcError: Error, Equatable { case invalid, divisionByZero }

    /// Returns nil when the input is not an arithmetic expression (caller falls back to search).
    public static func evaluate(_ input: String) -> Double? {
        let s = input.replacingOccurrences(of: "×", with: "*")
            .replacingOccurrences(of: "÷", with: "/")
            .replacingOccurrences(of: "，", with: ",")
            .replacingOccurrences(of: ",", with: "")
            .trimmingCharacters(in: .whitespaces)
        guard !s.isEmpty, s.contains(where: { "+-*/%^()".contains($0) }) else { return nil }
        guard s.allSatisfy({ $0.isNumber || " .+-*/%^()".contains($0) }) else { return nil }
        guard s.contains(where: { $0.isNumber }) else { return nil }
        var p = Parser(Array(s.filter { $0 != " " }))
        guard let v = try? p.parseExpression(), p.atEnd, v.isFinite else { return nil }
        // A bare negative number such as "-5" is not a calculation worth showing.
        if s.hasPrefix("-"), Double(s) != nil { return nil }
        return v
    }

    public static func format(_ value: Double) -> String {
        if value == value.rounded(), abs(value) < 1e15 { return String(Int64(value)) }
        let f = NumberFormatter()
        f.numberStyle = .decimal
        f.maximumFractionDigits = 10
        f.usesGroupingSeparator = false
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: NSNumber(value: value)) ?? String(value)
    }

    struct Parser {
        let c: [Character]
        var i = 0
        var depth = 0
        init(_ c: [Character]) { self.c = c }
        var atEnd: Bool { i == c.count }
        func peek() -> Character? { i < c.count ? c[i] : nil }

        mutating func parseExpression() throws -> Double {
            var v = try parseTerm()
            while let ch = peek(), ch == "+" || ch == "-" {
                i += 1
                let r = try parseTerm()
                v = ch == "+" ? v + r : v - r
            }
            return v
        }

        mutating func parseTerm() throws -> Double {
            var v = try parseFactor()
            while let ch = peek(), ch == "*" || ch == "/" || ch == "%" {
                i += 1
                let r = try parseFactor()
                switch ch {
                case "*": v *= r
                case "/": guard r != 0 else { throw CalcError.divisionByZero }; v /= r
                default: guard r != 0 else { throw CalcError.divisionByZero }; v = v.truncatingRemainder(dividingBy: r)
                }
            }
            return v
        }

        mutating func parseFactor() throws -> Double {
            let base = try parseUnary()
            if peek() == "^" {
                i += 1
                let exp = try parseFactor() // right associative
                return pow(base, exp)
            }
            return base
        }

        mutating func parseUnary() throws -> Double {
            if peek() == "-" { i += 1; return -(try parseUnary()) }
            if peek() == "+" { i += 1; return try parseUnary() }
            return try parsePrimary()
        }

        mutating func parsePrimary() throws -> Double {
            if peek() == "(" {
                depth += 1
                guard depth < 64 else { throw CalcError.invalid }
                i += 1
                let v = try parseExpression()
                guard peek() == ")" else { throw CalcError.invalid }
                i += 1
                depth -= 1
                return v
            }
            let start = i
            while let ch = peek(), ch.isNumber || ch == "." { i += 1 }
            guard i > start, let v = Double(String(c[start..<i])) else { throw CalcError.invalid }
            return v
        }
    }
}
