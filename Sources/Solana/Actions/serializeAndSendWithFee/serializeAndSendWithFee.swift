import Foundation
import RxSwift

extension Solana {
    func serializeAndSendWithFee(
        instructions: [TransactionInstruction],
        recentBlockhash: String? = nil,
        signers: [Account]
    ) -> Single<String> {
        let maxAttemps = 3
        var numberOfTries = 0
        return serializeTransaction(
            instructions: instructions,
            recentBlockhash: recentBlockhash,
            signers: signers
        )
        .flatMap {
            return self.sendTransaction(serializedTransaction: $0)
        }
        .catch {error in
            if numberOfTries <= maxAttemps,
               let error = error as? Solana.SolanaError {
                var shouldRetry = false
                switch error {
                case .other(let message) where message == "Blockhash not found":
                    shouldRetry = true
                case .invalidResponse(let response) where response.message == "Blockhash not found":
                    shouldRetry = true
                default:
                    break
                }
                
                if shouldRetry {
                    numberOfTries += 1
                    return self.serializeAndSendWithFee(instructions: instructions, signers: signers)
                }
            }
            throw error
        }
    }
    
    func serializeAndSendWithFeeSimulation(
        instructions: [TransactionInstruction],
        recentBlockhash: String? = nil,
        signers: [Account]
    ) -> Single<String> {
        let maxAttemps = 3
        var numberOfTries = 0
        return serializeTransaction(
            instructions: instructions,
            recentBlockhash: recentBlockhash,
            signers: signers
        )
        .flatMap {
            return self.simulateTransaction(transaction: $0)
                .map {result -> String in
                    if result.err != nil {
                        throw SolanaError.other("Simulation error")
                    }
                    return "<simulated transaction id>"
                }
            
        }
        .catch {error in
            if numberOfTries <= maxAttemps,
               let error = error as? SolanaError
            {
                var shouldRetry = false
                switch error {
                case .other(let message) where message == "Blockhash not found":
                    shouldRetry = true
                case .invalidResponse(let response) where response.message == "Blockhash not found":
                    shouldRetry = true
                default:
                    break
                }
                
                if shouldRetry {
                    numberOfTries += 1
                    return self.serializeAndSendWithFeeSimulation(instructions: instructions, signers: signers)
                }
            }
            throw error
        }
    }
    
    private func serializeTransaction(
        instructions: [TransactionInstruction],
        recentBlockhash: String? = nil,
        signers: [Account],
        feePayer: PublicKey? = nil
    ) -> Single<String> {
        // get recentBlockhash
        let getRecentBlockhashRequest: Single<String>
        if let recentBlockhash = recentBlockhash {
            getRecentBlockhashRequest = .just(recentBlockhash)
        } else {
            getRecentBlockhashRequest = getRecentBlockhash()
        }
        
        guard let feePayer = feePayer ?? accountStorage.account?.publicKey else {
            return .error(SolanaError.invalidRequest(reason: "Fee-payer not found"))
        }
        
        // serialize transaction
        return getRecentBlockhashRequest
            .map {recentBlockhash -> String in
                var transaction = Transaction(
                    feePayer: feePayer,
                    instructions: instructions,
                    recentBlockhash: recentBlockhash
                )
                try transaction.sign(signers: signers)
                guard let serializedTransaction = try transaction.serialize().bytes.toBase64() else {
                    throw SolanaError.other("Could not serialize transaction")
                }
                return serializedTransaction
            }
    }
}
