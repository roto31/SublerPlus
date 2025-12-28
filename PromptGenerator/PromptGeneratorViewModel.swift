import SwiftUI
import AppKit

enum PromptFramework: String, CaseIterable {
    case auto
    case rise
    case create
    case race
    case creo
    
    var displayName: String {
        switch self {
        case .auto: return "Auto-detected"
        case .rise: return "RISE Framework"
        case .create: return "CREATE Framework"
        case .race: return "RACE Framework"
        case .creo: return "CREO Framework"
        }
    }
}

class PromptGeneratorViewModel: ObservableObject {
    @Published var userInput: String = ""
    @Published var additionalContext: String = ""
    @Published var generatedPrompt: String = ""
    @Published var isGenerating: Bool = false
    @Published var usedFramework: PromptFramework?
    @Published var showCopyAlert: Bool = false
    
    func generatePrompt(framework: PromptFramework) {
        guard !userInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return
        }
        
        isGenerating = true
        generatedPrompt = ""
        
        // Simulate processing delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let selectedFramework = framework == .auto ? self.detectFramework() : framework
            self.usedFramework = selectedFramework
            self.generatedPrompt = self.buildPrompt(framework: selectedFramework)
            self.isGenerating = false
        }
    }
    
    private func detectFramework() -> PromptFramework {
        let input = userInput.lowercased()
        
        // Detection logic based on keywords and task type
        if input.contains("analyze") || input.contains("evaluate") || input.contains("compare") {
            return .race
        } else if input.contains("create") || input.contains("generate") || input.contains("write") {
            return .create
        } else if input.contains("research") || input.contains("explore") || input.contains("investigate") {
            return .rise
        } else if input.contains("problem") || input.contains("solve") || input.contains("solution") {
            return .creo
        }
        
        // Default to CREATE for creative tasks
        return .create
    }
    
    private func buildPrompt(framework: PromptFramework) -> String {
        let trimmedInput = userInput.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContext = additionalContext.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch framework {
        case .rise:
            return buildRISEPrompt(task: trimmedInput, context: trimmedContext)
        case .create:
            return createCREATEPrompt(task: trimmedInput, context: trimmedContext)
        case .race:
            return buildRACEPrompt(task: trimmedInput, context: trimmedContext)
        case .creo:
            return buildCREOPrompt(task: trimmedInput, context: trimmedContext)
        case .auto:
            return buildRISEPrompt(task: trimmedInput, context: trimmedContext) // Fallback
        }
    }
    
    // RISE Framework: Research, Ideate, Synthesize, Execute
    private func buildRISEPrompt(task: String, context: String) -> String {
        var prompt = "<role>\nYou are an expert AI assistant specialized in research and analysis.\n</role>\n\n"
        prompt += "<task>\n\(task)\n</task>\n\n"
        
        if !context.isEmpty {
            prompt += "<context>\n\(context)\n</context>\n\n"
        }
        
        prompt += "<framework>RISE</framework>\n\n"
        prompt += "<instructions>\n"
        prompt += "1. RESEARCH: Gather comprehensive information about the topic\n"
        prompt += "2. IDEATE: Generate multiple perspectives and approaches\n"
        prompt += "3. SYNTHESIZE: Combine insights into coherent understanding\n"
        prompt += "4. EXECUTE: Provide actionable recommendations or solutions\n"
        prompt += "</instructions>\n\n"
        prompt += "<output_requirements>\n"
        prompt += "- Provide clear, structured response\n"
        prompt += "- Cite sources or reasoning where applicable\n"
        prompt += "- Include actionable next steps\n"
        prompt += "</output_requirements>"
        
        return prompt
    }
    
    // CREATE Framework: Context, Request, Examples, Adjustments, Type, Extras
    private func createCREATEPrompt(task: String, context: String) -> String {
        var prompt = "<role>\nYou are a creative and versatile AI assistant.\n</role>\n\n"
        prompt += "<context>\n"
        if !context.isEmpty {
            prompt += "\(context)\n\n"
        }
        prompt += "Task: \(task)\n"
        prompt += "</context>\n\n"
        
        prompt += "<request>\n"
        prompt += "\(task)\n"
        prompt += "</request>\n\n"
        
        prompt += "<framework>CREATE</framework>\n\n"
        prompt += "<instructions>\n"
        prompt += "- Provide clear, well-structured output\n"
        prompt += "- Use appropriate formatting and style\n"
        prompt += "- Ensure completeness and accuracy\n"
        prompt += "- Adapt tone to the context\n"
        prompt += "</instructions>\n\n"
        prompt += "<output_requirements>\n"
        prompt += "- High quality and professional\n"
        prompt += "- Relevant to the request\n"
        prompt += "- Comprehensive yet concise\n"
        prompt += "</output_requirements>"
        
        return prompt
    }
    
    // RACE Framework: Restate, Answer, Cite, Explain
    private func buildRACEPrompt(task: String, context: String) -> String {
        var prompt = "<role>\nYou are an analytical AI assistant that provides well-reasoned, evidence-based responses.\n</role>\n\n"
        prompt += "<question>\n\(task)\n</question>\n\n"
        
        if !context.isEmpty {
            prompt += "<background>\n\(context)\n</background>\n\n"
        }
        
        prompt += "<framework>RACE</framework>\n\n"
        prompt += "<instructions>\n"
        prompt += "1. RESTATE: Paraphrase the question to show understanding\n"
        prompt += "2. ANSWER: Provide a clear, direct answer to the question\n"
        prompt += "3. CITE: Reference specific evidence, data, or reasoning\n"
        prompt += "4. EXPLAIN: Elaborate on how the evidence supports your answer\n"
        prompt += "</instructions>\n\n"
        prompt += "<output_requirements>\n"
        prompt += "- Direct and precise answer\n"
        prompt += "- Well-supported with evidence\n"
        prompt += "- Logical flow of reasoning\n"
        prompt += "</output_requirements>"
        
        return prompt
    }
    
    // CREO Framework: Challenge, Response, Evidence, Outcome
    private func buildCREOPrompt(task: String, context: String) -> String {
        var prompt = "<role>\nYou are a problem-solving AI assistant focused on delivering practical solutions.\n</role>\n\n"
        prompt += "<challenge>\n\(task)\n</challenge>\n\n"
        
        if !context.isEmpty {
            prompt += "<situation>\n\(context)\n</situation>\n\n"
        }
        
        prompt += "<framework>CREO</framework>\n\n"
        prompt += "<instructions>\n"
        prompt += "1. CHALLENGE: Clearly define the problem or challenge\n"
        prompt += "2. RESPONSE: Propose a solution or approach\n"
        prompt += "3. EVIDENCE: Provide reasoning, data, or examples supporting the solution\n"
        prompt += "4. OUTCOME: Describe expected results and implementation steps\n"
        prompt += "</instructions>\n\n"
        prompt += "<output_requirements>\n"
        prompt += "- Practical and actionable solution\n"
        prompt += "- Well-reasoned approach\n"
        prompt += "- Clear implementation path\n"
        prompt += "- Measurable outcomes\n"
        prompt += "</output_requirements>"
        
        return prompt
    }
    
    func copyToClipboard() {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(generatedPrompt, forType: .string)
        showCopyAlert = true
    }
}

