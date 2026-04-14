// GeminiService.swift
// Gemini 1.5 Flash API client used for:
//   1. Parsing nutrition data from MyNetDiary screenshots
//   2. Analyzing progress photos for body composition changes
// All calls are on-device → API → response. Requires network.

import Foundation
import UIKit

enum GeminiService {
    private static let apiKey = "AIzaSyAbK8j4SsqrX7_2hARXNnWBxcfag2uNc2g"
    private static let baseURL = "https://generativelanguage.googleapis.com/v1beta/models/gemini-1.5-flash:generateContent"

    // MARK: - Nutrition Result
    struct NutritionResult {
        var calories: Int?
        var protein: Int?
        var carbs: Int?
        var fat: Int?
        var rawResponse: String = ""
    }

    // MARK: - Parse MyNetDiary Screenshot
    /// Sends the screenshot to Gemini Vision and extracts daily totals.
    static func parseNutritionScreenshot(_ image: UIImage) async throws -> NutritionResult {
        guard let data = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError.imageEncodingFailed
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

        let body: [String: Any] = [
            "contents": [[
                "parts": [
                    ["text": prompt],
                    ["inline_data": ["mime_type": "image/jpeg", "data": b64]]
                ]
            ]],
            "generationConfig": ["temperature": 0.1, "maxOutputTokens": 200]
        ]

        let text = try await callAPI(body: body)
        return parseNutritionJSON(text)
    }

    // MARK: - Analyze Progress Photo(s)
    /// Analyzes current photo solo, or compares current vs. previous if provided.
    static func analyzeProgressPhoto(current: UIImage, previous: UIImage? = nil) async throws -> String {
        guard let curData = current.jpegData(compressionQuality: 0.75) else {
            throw GeminiError.imageEncodingFailed
        }

        var parts: [[String: Any]] = []

        if let prev = previous, let prevData = prev.jpegData(compressionQuality: 0.75) {
            parts.append(["text": """
            These are progress photos from a personal fat-loss program.
            Image 1 is OLDER, Image 2 is MORE RECENT.
            Provide a brief, objective, clinical analysis comparing visible body composition changes.
            Focus on observable differences: muscle definition, waist/midsection, overall leanness.
            Keep it under 80 words. Be direct and factual — no motivational language.
            """])
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": prevData.base64EncodedString()]])
            parts.append(["text": "More recent photo:"])
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": curData.base64EncodedString()]])
        } else {
            parts.append(["text": """
            This is a progress photo from a personal fat-loss program.
            Briefly describe the visible body composition — estimated leanness, muscle visibility, midsection.
            Under 60 words. Be direct and factual — no motivational language.
            """])
            parts.append(["inline_data": ["mime_type": "image/jpeg", "data": curData.base64EncodedString()]])
        }

        let body: [String: Any] = [
            "contents": [["parts": parts]],
            "generationConfig": ["temperature": 0.2, "maxOutputTokens": 300]
        ]

        return try await callAPI(body: body)
    }

    // MARK: - Private: HTTP call
    private static func callAPI(body: [String: Any]) async throws -> String {
        guard let url = URL(string: "\(baseURL)?key=\(apiKey)") else {
            throw GeminiError.badURL
        }
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: body)
        req.timeoutInterval = 30

        let (data, resp) = try await URLSession.shared.data(for: req)

        guard let http = resp as? HTTPURLResponse else {
            throw GeminiError.networkError("No HTTP response")
        }
        guard http.statusCode == 200 else {
            let msg = String(data: data, encoding: .utf8) ?? "unknown"
            throw GeminiError.apiError(http.statusCode, msg)
        }

        // Extract text from response
        let json = try JSONSerialization.jsonObject(with: data) as? [String: Any]
        let candidates = json?["candidates"] as? [[String: Any]]
        let content = candidates?.first?["content"] as? [String: Any]
        let parts = content?["parts"] as? [[String: Any]]
        guard let text = parts?.first?["text"] as? String else {
            throw GeminiError.noContent
        }
        return text
    }

    // MARK: - Private: Parse nutrition JSON from model response
    private static func parseNutritionJSON(_ raw: String) -> NutritionResult {
        var cleaned = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        // Strip markdown code fences if present
        cleaned = cleaned.replacingOccurrences(of: "```json", with: "")
        cleaned = cleaned.replacingOccurrences(of: "```", with: "")
        // Extract first {...} block
        if let s = cleaned.firstIndex(of: "{"), let e = cleaned.lastIndex(of: "}") {
            cleaned = String(cleaned[s...e])
        }
        guard let data = cleaned.data(using: .utf8),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            return NutritionResult(rawResponse: raw)
        }
        // Values may come as Int or Double from JSON
        func intVal(_ key: String) -> Int? {
            if let i = dict[key] as? Int { return i }
            if let d = dict[key] as? Double { return Int(d) }
            return nil
        }
        return NutritionResult(
            calories: intVal("calories"),
            protein: intVal("protein"),
            carbs: intVal("carbs"),
            fat: intVal("fat"),
            rawResponse: raw
        )
    }

    // MARK: - Errors
    enum GeminiError: LocalizedError {
        case imageEncodingFailed
        case badURL
        case networkError(String)
        case apiError(Int, String)
        case noContent

        var errorDescription: String? {
            switch self {
            case .imageEncodingFailed:       return "Failed to encode image as JPEG."
            case .badURL:                    return "Invalid Gemini API URL."
            case .networkError(let msg):     return "Network error: \(msg)"
            case .apiError(let code, let msg): return "Gemini API error \(code): \(msg.prefix(200))"
            case .noContent:                 return "Gemini returned no content."
            }
        }
    }
}
