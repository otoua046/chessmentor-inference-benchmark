import Foundation

/// Provides a simple interface to request the best chess move from a FEN position
/// using a Stockfish-based inference service. Conforms to `BestMoveProvider` so it can be
/// swapped for alternate chess engines or mocked in tests.
struct StockfishBestMoveProvider: BestMoveProvider {

    /// Internal chess engine service wrapper responsible for sending FEN queries to Stockfish
    /// and returning parsed results.
    private let service = StockfishService()

    /// Requests a best move from Stockfish using the given FEN string.
    ///
    /// - Converts the engine evaluation (if present) into a `Double`
    /// - Wraps the returned UCI and SAN strings in a unified `EngineResult` model
    /// - The PV (principal variation) is not returned by this implementation and remains `nil`
    ///
    /// Uses Swift async/await to perform a non-blocking engine query.
    func bestMove(for fen: String) async throws -> EngineResult {
        let r = try await service.bestMove(for: fen)

        // Parse engine evaluation from optional string to numeric type.
        // If parsing fails, result becomes NaN (using Double initializer behavior).
        let eval = Double(r.evaluation ?? "")

        // Package the output in a consistent return type. PV is omitted for this provider.
        return EngineResult(
            uci: r.best_move_uci,
            san: r.best_move_san,
            evaluation: eval,
            pv: nil
        )
    }
}
