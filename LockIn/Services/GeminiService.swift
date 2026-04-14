// GeminiService.swift
// AI vision service — now backed by Claude (Anthropic) instead of Gemini.
// Kept the same name and public API so call sites don't need changes.
//
// Uses:
//   1. parseNutritionScreenshot — extracts daily macro totals from an MND screenshot
//   2. analyzeProgressPhoto — body composition comparison between photos

import Foundation
import UIKit

enum GeminiService {
    private static let apiKey = SecretsStore.anthropicAPIKey
    private static let baseURL = "https://api.anthropic.com/v1/messages"
    private static let model   = "claude-haiku-4-5-20251001"

    // MARK: - Nutrition Result
    struct NutritionResult {
        var calories: Int?
        var protein:  Int?
        var carbs:    Int?
        var fat:      Int?
        var rawResponse: String = ""
    }

    // MARK: - Parse MyNetDiary Screenshot
    static func parseNutritionScreenshot(_ image: UIImage) async throws -> NutritionResult {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw AIError.imageEncodingFailed
        }
        let b64 = data.base64EncodedString()

        let prompt = """
        This is a screenshot from the MyNetDiary calorie tracking app showing a food diary or nutrition summary.
        Extract the TOTAL daily values for the entire day:
        - Total Calories (integer, e.g. 1847)
        - Total Protein in grams (integer, e.g. 138)
        - Total Carbohydrates in grams (integer, e.g. 210)
        - Total Fat in grams (integer, e.g. 55)

        Look for rows labeled "Total", "Totals", or summary rows at the bottom.
        Return ONLY a valid JSON object with these exact keys: calories, protein, carbs, fat
        Example: {"calories": 1847, "protein": 138, "carbs": 210, "fat": 55}
        Use null for any value you cannot find with confidence. Return ONLY the JSON — no other text.
        """

        let content: [[String: Any]] = [
            [
                "type": "image",
                "source": [
                    "type": "base64",
                    "media_type": "image/jpeg",
                    "data": b64
                ]
            ],
            ["type": "text", "text": prompt]
        ]

        let text = try await callAPI(content: content, maxTokens: 256)
        return parseNutritionJSON(text)
    }

    // MARK: - Analyze Progress Photo(s)
    static func analyzeProgressPhoto(current: UIImage, previous: UIImage? = nil) async throws -> String {
        guard let curData = current.jpegData(compressionQuality: 0.75) else {
            throw AIError.imageEncodingFailed
        }

        var content: [[String: Any]] = []

        if let prev = previous, let prevData = prev.jpegData(compressionQuality: 0.75) {
            content.append(["type": "text", "text": "These are progress photos from a personal fat-loss program. Image 1 is OLDER, Image 2 is MORE RECENT. Provide a brief, objective, clinical analysis comparing visible body composition changes. Focus on observable differences: muscle definition, waist/midsection, overall leanness. Keep it under 80 words. Be direct and factual — no motivational language."])
            content.append(["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": prevData.base64EncodedString()]])
            content.append(["type": "text", "text": "More recent photo:"])
            content.append(["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": curData.base64EncodedString()]])
        } else {
            content.append(["type": "text", "text": "This is a progress photo from a personal fat-loss program. Briefly describe the visible body composition — estimated leanness, muscle visibility, midsection. Under 60 words. Be direct and factual — no motivational language."])
            content.append(["type": "image", "source": ["type": "base64", "media_type": "image/jpeg", "data": curData.base64EncodedString()]])
        }

        return try await callAPI(content: content, maxTokens: 300)
    }

    // MARK: - Private: Claude Messages API call
    private static func callAPI(content: [[String: Any]], maxTokens: Int) async throws -> String {
        guard let url = URL(string: baseURL) else { throw AIError.badURL }

        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json",        forHTTPHeaderField: "Content-Type")
        req.setValue(apiKey,                    forHTTPHeaderField: "x-api-key")
        req.setValue("2023-06-01",              forHTTPHeaderField: "anthropic-version")
        req.timeoutInterval = 30

        let body: [String: Any] = [
            "model":      model,
            "max_tokens": maxTokens,
            "messages": [
                ["role": "user", "content": content]
            ]
        ]
        req.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse else {
            throw AIError.networkError("No HTTP response")
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw AIError.apiError(http.statusCode, msg)
        }

        // Parse Claude response: content[0].text
        let json     = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let contents = json?["content"] as? [[String: Any]]
        guard let text = contents?.first?["text"] as? String else {
            throw AIError.noContent
        }
        return text
    }

    // MARK: - Private: Parse nutrition JSON from model response
    private static func parseNutritionJSON(_ raw: String) -> NutritionResult {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        if let s = cleaned.firstIndex(of: "{"), let e = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[s...e])
        }
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return NutritionResult(rawResponse: raw)
        }
        func intVal(_ key: String) -> Int? {
            if let i = dict[key] as? Int    { return i }
            if let d = dict[key] as? Double { return Int(d) }
            return nil
        }
        return NutritionResult(
            calories: intVal("calories"),
            protein:  intVal("protein"),
            carbs:    intVal("carbs"),
            fat:      intVal("fat"),
            rawResponse: raw
        )
    }

    // MARK: - Errors
    enum AIError: LocalizedError {
        case imageEncodingFailed
        case badURL
        case networkError(String)
        case apiError(Int, String)
        case noContent

        var errorDescription: String? {
            switch self {
            case .imageEncodingFailed:           return "Failed to encode image as JPEG."
            case .badURL:                        return "Invalid API URL."
            case .networkError(let msg):         return "Network error: \(msg)"
            case .apiError(let code, let msg):   return "API error \(code): \(msg.prefix(200))"
            case .noContent:                     return "No content in response."
            }
        }
    }
}
