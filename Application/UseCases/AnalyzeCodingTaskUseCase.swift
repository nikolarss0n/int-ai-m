import Foundation

/// Use case for analyzing coding task screenshots with AI
class AnalyzeCodingTaskUseCase {

    private let apiClient: AnthropicApiClient
    private let session: CodingSession

    enum AnalysisError: Error, LocalizedError {
        case noScreenshots
        case apiError(String)
        case noApiKey

        var errorDescription: String? {
            switch self {
            case .noScreenshots:
                return "No screenshots to analyze. Please capture at least one screenshot."
            case .apiError(let message):
                return "API error: \(message)"
            case .noApiKey:
                return "API key not configured. Please add your Anthropic API key in settings."
            }
        }
    }

    init(apiClient: AnthropicApiClient, session: CodingSession) {
        self.apiClient = apiClient
        self.session = session
    }

    /// Execute the use case
    /// - Parameter customPrompt: Optional custom prompt (uses default if nil)
    /// - Returns: The analysis result
    func execute(customPrompt: String? = nil) async -> Result<Analysis, AnalysisError> {
        // Validate session has screenshots
        guard session.hasScreenshots else {
            return .failure(.noScreenshots)
        }

        // Get screenshots as base64
        let imageBase64Strings = session.screenshotsAsBase64

        // Build prompt
        let prompt = customPrompt ?? buildDefaultPrompt()

        // Call API
        let apiResult = await apiClient.sendMessage(
            images: imageBase64Strings,
            prompt: prompt,
            model: AppConstants.Models.anthropicHaiku
        )

        switch apiResult {
        case .success(let responseText):
            // Parse response into Analysis
            let analysis = Analysis.fromMarkdown(responseText)

            // Store in session
            session.setAnalysis(analysis)

            return .success(analysis)

        case .failure(let error):
            return .failure(.apiError(error.localizedDescription))
        }
    }

    private func buildDefaultPrompt() -> String {
        return codingInterviewStepsPrompt(
            language: AppSettings.shared.programmingLanguage.codeBlockLang,
            task: "Analyze the screenshot(s) of the coding problem and implement it as typed steps."
        )
    }
}
