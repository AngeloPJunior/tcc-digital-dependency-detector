import SwiftUI
import CoreML

struct ContentView: View {
    @State private var riskScore: Double = 0.0
    @State private var riskLevel: String = "—"
    @State private var riskColor: Color = .gray
    @State private var confidences: [String: Double] = [:]
    @State private var showingPredictionSheet = false
    @State private var predictions: [PredictionRecord] = []
    
    // Input fields
    @State private var avgDailySessions: String = "20"
    @State private var avgDailyEvents: String = "1000"
    @State private var avgUniqueApps: String = "10"
    @State private var avgNightRatio: String = "0.20"
    @State private var avgSessionDuration: String = "300"
    @State private var avgShortSessionRatio: String = "0.15"
    @State private var avgTopAppRatio: String = "0.40"
    @State private var avgEntropy: String = "1.5"
    @State private var avgReopeningIndex: String = "0.70"
    @State private var avgInterSession: String = "60"
    @State private var stdDailySessions: String = "10"
    @State private var maxDailySessions: String = "40"
    @State private var escalationRate: String = "1.0"
    
    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.05, green: 0.1, blue: 0.2),
                    Color(red: 0.1, green: 0.15, blue: 0.25)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()
            
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 12) {
                    Text("Digital Dependency Detector")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                    
                    Text("Risk Classification System")
                        .font(.caption)
                        .foregroundColor(.gray)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(Color.black.opacity(0.3))
                
                // Main content
                ScrollView {
                    VStack(spacing: 24) {
                        // Risk Score Card
                        VStack(spacing: 16) {
                            Text("Current Risk Level")
                                .font(.headline)
                                .foregroundColor(.white)
                            
                            ZStack {
                                Circle()
                                    .fill(riskColor.opacity(0.2))
                                    .frame(height: 180)
                                
                                VStack(spacing: 8) {
                                    Text(riskLevel)
                                        .font(.system(size: 48, weight: .bold))
                                        .foregroundColor(riskColor)
                                    
                                    Text("\(Int(riskScore))%")
                                        .font(.title3)
                                        .foregroundColor(.gray)
                                }
                            }
                            
                            // Confidence breakdown
                            if !confidences.isEmpty {
                                VStack(spacing: 8) {
                                    ForEach(["LOW", "MEDIUM", "HIGH"], id: \.self) { level in
                                        HStack {
                                            Text(level)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .frame(width: 50, alignment: .leading)
                                            
                                            GeometryReader { geometry in
                                                ZStack(alignment: .leading) {
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(Color.gray.opacity(0.2))
                                                    
                                                    RoundedRectangle(cornerRadius: 4)
                                                        .fill(colorForLevel(level))
                                                        .frame(width: geometry.size.width * CGFloat(confidences[level] ?? 0))
                                                }
                                            }
                                            .frame(height: 8)
                                            
                                            Text("\(Int((confidences[level] ?? 0) * 100))%")
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                                .frame(width: 40, alignment: .trailing)
                                        }
                                    }
                                }
                                .padding(12)
                                .background(Color.white.opacity(0.05))
                                .cornerRadius(8)
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        
                        // Quick Test Buttons
                        VStack(spacing: 12) {
                            Text("Quick Test Scenarios")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity, alignment: .leading)
                            
                            HStack(spacing: 12) {
                                Button(action: { loadLowRiskScenario() }) {
                                    VStack(spacing: 4) {
                                        Text("🟢")
                                            .font(.title3)
                                        Text("Low Risk")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.green.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { loadMediumRiskScenario() }) {
                                    VStack(spacing: 4) {
                                        Text("🟡")
                                            .font(.title3)
                                        Text("Medium Risk")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.yellow.opacity(0.2))
                                    .cornerRadius(8)
                                }
                                
                                Button(action: { loadHighRiskScenario() }) {
                                    VStack(spacing: 4) {
                                        Text("🔴")
                                            .font(.title3)
                                        Text("High Risk")
                                            .font(.caption)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(12)
                                    .background(Color.red.opacity(0.2))
                                    .cornerRadius(8)
                                }
                            }
                        }
                        .padding(20)
                        .background(Color.white.opacity(0.08))
                        .cornerRadius(12)
                        
                        // Predict Button
                        Button(action: { predictRisk() }) {
                            HStack {
                                Image(systemName: "sparkles")
                                Text("Predict Risk")
                                    .fontWeight(.semibold)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(14)
                            .background(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.blue,
                                        Color.cyan
                                    ]),
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .foregroundColor(.white)
                            .cornerRadius(10)
                        }
                        
                        // History Section
                        if !predictions.isEmpty {
                            VStack(spacing: 12) {
                                Text("Prediction History")
                                    .font(.headline)
                                    .foregroundColor(.white)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                
                                ForEach(predictions.prefix(5), id: \.id) { prediction in
                                    HStack {
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(prediction.riskLevel)
                                                .font(.caption)
                                                .foregroundColor(.gray)
                                            Text(prediction.timestamp, style: .time)
                                                .font(.caption2)
                                                .foregroundColor(.gray)
                                        }
                                        
                                        Spacer()
                                        
                                        Text("\(Int(prediction.score))%")
                                            .font(.headline)
                                            .foregroundColor(colorForLevel(prediction.riskLevel))
                                    }
                                    .padding(12)
                                    .background(Color.white.opacity(0.05))
                                    .cornerRadius(8)
                                }
                            }
                            .padding(20)
                            .background(Color.white.opacity(0.08))
                            .cornerRadius(12)
                        }
                    }
                    .padding(20)
                }
            }
        }
    }
    
    // MARK: - Methods
    
    func predictRisk() {
        // Parse input values
        guard let sessions = Double(avgDailySessions),
              let events = Double(avgDailyEvents),
              let apps = Double(avgUniqueApps),
              let nightRatio = Double(avgNightRatio),
              let duration = Double(avgSessionDuration),
              let shortRatio = Double(avgShortSessionRatio),
              let topAppRatio = Double(avgTopAppRatio),
              let entropy = Double(avgEntropy),
              let reopening = Double(avgReopeningIndex),
              let interSession = Double(avgInterSession),
              let stdSessions = Double(stdDailySessions),
              let maxSessions = Double(maxDailySessions),
              let escalation = Double(escalationRate) else {
            return
        }
        
        // Create input for CoreML model
        let input = RiskClassifierInput(
            avg_daily_sessions: NSNumber(value: sessions),
            avg_daily_events: NSNumber(value: events),
            avg_unique_apps: NSNumber(value: apps),
            avg_night_ratio: NSNumber(value: nightRatio),
            avg_session_duration: NSNumber(value: duration),
            avg_short_session_ratio: NSNumber(value: shortRatio),
            avg_top_app_ratio: NSNumber(value: topAppRatio),
            avg_entropy: NSNumber(value: entropy),
            avg_reopening_index: NSNumber(value: reopening),
            avg_inter_session: NSNumber(value: interSession),
            std_daily_sessions: NSNumber(value: stdSessions),
            max_daily_sessions: NSNumber(value: maxSessions),
            escalation_rate: NSNumber(value: escalation)
        )
        
        do {
            let model = try RiskClassifier(configuration: MLModelConfiguration())
            let output = try model.prediction(input: input)
            
            // Get prediction
            let predictedClass = output.risk_level.intValue
            let riskLevelNames = ["LOW", "MEDIUM", "HIGH"]
            let predictedRiskLevel = riskLevelNames[predictedClass]
            
            // Get probabilities
            if let probabilities = output.risk_levelProbability as? [NSNumber: NSNumber] {
                let lowProb = probabilities[NSNumber(value: 0)]?.doubleValue ?? 0
                let mediumProb = probabilities[NSNumber(value: 1)]?.doubleValue ?? 0
                let highProb = probabilities[NSNumber(value: 2)]?.doubleValue ?? 0
                
                confidences = [
                    "LOW": lowProb,
                    "MEDIUM": mediumProb,
                    "HIGH": highProb
                ]
                
                // Set the highest probability as the score
                let maxProb = max(lowProb, mediumProb, highProb)
                riskScore = maxProb * 100
            }
            
            riskLevel = predictedRiskLevel
            riskColor = colorForLevel(predictedRiskLevel)
            
            // Add to history
            let record = PredictionRecord(
                riskLevel: predictedRiskLevel,
                score: riskScore,
                timestamp: Date()
            )
            predictions.insert(record, at: 0)
            
        } catch {
            print("Error making prediction: \(error)")
        }
    }
    
    func colorForLevel(_ level: String) -> Color {
        switch level {
        case "LOW":
            return .green
        case "MEDIUM":
            return .yellow
        case "HIGH":
            return .red
        default:
            return .gray
        }
    }
    
    func loadLowRiskScenario() {
        avgDailySessions = "8"
        avgDailyEvents = "200"
        avgUniqueApps = "12"
        avgNightRatio = "0.02"
        avgSessionDuration = "600"
        avgShortSessionRatio = "0.1"
        avgTopAppRatio = "0.25"
        avgEntropy = "2.1"
        avgReopeningIndex = "0.2"
        avgInterSession = "90"
        stdDailySessions = "3"
        maxDailySessions = "12"
        escalationRate = "0.9"
        
        predictRisk()
    }
    
    func loadMediumRiskScenario() {
        avgDailySessions = "22"
        avgDailyEvents = "1200"
        avgUniqueApps = "9"
        avgNightRatio = "0.18"
        avgSessionDuration = "250"
        avgShortSessionRatio = "0.25"
        avgTopAppRatio = "0.45"
        avgEntropy = "1.3"
        avgReopeningIndex = "0.65"
        avgInterSession = "50"
        stdDailySessions = "8"
        maxDailySessions = "35"
        escalationRate = "1.1"
        
        predictRisk()
    }
    
    func loadHighRiskScenario() {
        avgDailySessions = "40"
        avgDailyEvents = "5000"
        avgUniqueApps = "5"
        avgNightRatio = "0.35"
        avgSessionDuration = "120"
        avgShortSessionRatio = "0.6"
        avgTopAppRatio = "0.7"
        avgEntropy = "0.8"
        avgReopeningIndex = "0.85"
        avgInterSession = "20"
        stdDailySessions = "15"
        maxDailySessions = "60"
        escalationRate = "1.5"
        
        predictRisk()
    }
}

// MARK: - Data Models

struct PredictionRecord: Identifiable {
    let id = UUID()
    let riskLevel: String
    let score: Double
    let timestamp: Date
}

#Preview {
    ContentView()
}
