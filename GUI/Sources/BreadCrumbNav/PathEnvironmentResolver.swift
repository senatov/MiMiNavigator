//
//  PathEnvironmentResolver.swift
//  MiMiNavigator
//
//  Created by Codex on 25.04.2026.
//  Copyright © 2026 Senatov. All rights reserved.
//

import Foundation

enum PathEnvironmentResolver {
    struct Expansion {
        let original: String
        let expanded: String
        let containsVariable: Bool
    }

    private struct FirstVariable {
        let token: String
        let value: String
        let range: Range<String.Index>
    }

    static func expand(_ input: String) -> Expansion? {
        var output = ""
        var index = input.startIndex
        var containsVariable = false
        let environment = ProcessInfo.processInfo.environment

        while index < input.endIndex {
            let char = input[index]
            guard char == "$" else {
                output.append(char)
                index = input.index(after: index)
                continue
            }

            if let variable = parseVariable(in: input, at: index, environment: environment) {
                output.append(variable.value)
                containsVariable = true
                index = variable.range.upperBound
                continue
            }

            guard !startsVariableSyntax(in: input, at: index) else {
                return nil
            }

            output.append(char)
            index = input.index(after: index)
        }

        return Expansion(original: input, expanded: output, containsVariable: containsVariable)
    }

    static func symbolicPath(forResolvedPath resolvedPath: String, preserving symbolicPath: String?) -> String? {
        guard let symbolicPath,
              let variable = firstVariable(in: symbolicPath),
              let expansion = expand(symbolicPath)
        else {
            return nil
        }

        let symbolicRoot = String(symbolicPath[..<variable.range.upperBound])
        let prefixBeforeVariable = String(symbolicPath[..<variable.range.lowerBound])
        let expandedPrefix = expand(prefixBeforeVariable)?.expanded ?? prefixBeforeVariable
        let expandedRoot = expandedPrefix + variable.value
        let normalizedRoot = normalizePath(expandedRoot)
        let normalizedResolved = normalizePath(resolvedPath)

        guard normalizedResolved == normalizedRoot || normalizedResolved.hasPrefix(normalizedRoot + "/") else {
            return nil
        }

        let suffix = normalizedResolved.dropFirst(normalizedRoot.count)
        return symbolicRoot + suffix
    }

    static func displayComponents(from path: String) -> [BreadCrumbDisplayComponent] {
        path.split(separator: "/")
            .map(String.init)
            .filter { !$0.isEmpty }
            .map { component in
                BreadCrumbDisplayComponent(text: component, isEnvironmentVariable: component.hasPrefix("$"))
            }
    }

    private static func firstVariable(in input: String) -> FirstVariable? {
        let environment = ProcessInfo.processInfo.environment
        var index = input.startIndex
        while index < input.endIndex {
            if input[index] == "$",
               let variable = parseVariable(in: input, at: index, environment: environment)
            {
                return variable
            }
            index = input.index(after: index)
        }
        return nil
    }

    private static func parseVariable(
        in input: String,
        at dollarIndex: String.Index,
        environment: [String: String]
    ) -> FirstVariable? {
        let next = input.index(after: dollarIndex)
        guard next < input.endIndex else { return nil }

        if input[next] == "{" {
            let nameStart = input.index(after: next)
            guard let close = input[nameStart...].firstIndex(of: "}") else { return nil }
            let name = String(input[nameStart..<close])
            guard isValidName(name), let value = environment[name] else { return nil }
            return FirstVariable(
                token: "${\(name)}",
                value: value,
                range: dollarIndex..<input.index(after: close)
            )
        }

        guard isValidNameStart(input[next]) else { return nil }
        var end = input.index(after: next)
        while end < input.endIndex, isValidNameBody(input[end]) {
            end = input.index(after: end)
        }

        let name = String(input[next..<end])
        guard let value = environment[name] else { return nil }
        return FirstVariable(token: "$\(name)", value: value, range: dollarIndex..<end)
    }

    private static func startsVariableSyntax(in input: String, at dollarIndex: String.Index) -> Bool {
        let next = input.index(after: dollarIndex)
        guard next < input.endIndex else { return false }
        return input[next] == "{" || isValidNameStart(input[next])
    }

    private static func isValidName(_ name: String) -> Bool {
        guard let first = name.first, isValidNameStart(first) else { return false }
        return name.dropFirst().allSatisfy(isValidNameBody)
    }

    private static func isValidNameStart(_ char: Character) -> Bool {
        char == "_" || char.isLetter
    }

    private static func isValidNameBody(_ char: Character) -> Bool {
        isValidNameStart(char) || char.isNumber
    }

    private static func normalizePath(_ path: String) -> String {
        URL(fileURLWithPath: path).standardizedFileURL.path
    }
}

struct BreadCrumbDisplayComponent: Equatable {
    let text: String
    let isEnvironmentVariable: Bool
}
