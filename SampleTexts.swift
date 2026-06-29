import Foundation

struct SampleTexts {
    struct Sample {
        let title: String
        let text: String
    }
    
    static let all: [Sample] = [
        Sample(title: "Physics (Mago’s)",
               text: "Class 11 Physics\nQ1. A car starts from rest and accelerates uniformly at 2 m/s² for 10 s.\nFind (a) final velocity (b) distance covered.\n\nSolution:\nu = 0, a = 2 m/s², t = 10 s\nv = u + at = 0 + 2×10 = 20 m/s\ns = ut + ½at² = 0 + ½×2×100 = 100 m"),
        Sample(title: "Chemistry",
               text: "Class 11 Chemistry\nQ2. Balance the equation:\nFe + H₂O → Fe₃O₄ + H₂\n\nAnswer:\n3Fe + 4H₂O → Fe₃O₄ + 4H₂"),
        Sample(title: "Maths",
               text: "Class 11 Mathematics\nProve that √2 is irrational.\nProof: Assume √2 = p/q (in lowest terms)…"),
        Sample(title: "English Essay",
               text: "The importance of reading cannot be overstated. Books open doors to new worlds…")
    ]
}