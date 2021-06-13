import Foundation
import RxSwift

extension Solana {
    func getConfirmedTransaction(transactionSignature: String) -> Single<TransactionInfo> {
        Single.create { emitter in
            self.getConfirmedTransaction(transactionSignature: transactionSignature) {
                switch $0 {
                case .success(let transactions):
                    emitter(.success(transactions))
                case .failure(let error):
                    emitter(.failure(error))
                }
            }
            return Disposables.create()
        }
    }
}
