//	
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

class MainTabBarController: UITabBarController {
    
    var friendsCache: FriendsCache!
	
	convenience init(friendsCache: FriendsCache) {
		self.init(nibName: nil, bundle: nil)
        self.friendsCache = friendsCache
		self.setupViewController()
	}

	private func setupViewController() {
		viewControllers = [
			makeNav(for: makeFriendsList(), title: "Friends", icon: "person.2.fill"),
			makeTransfersList(),
			makeNav(for: makeCardsList(), title: "Cards", icon: "creditcard.fill")
		]
	}
	
	private func makeNav(for vc: UIViewController, title: String, icon: String) -> UIViewController {
		vc.navigationItem.largeTitleDisplayMode = .always
		
		let nav = UINavigationController(rootViewController: vc)
		nav.tabBarItem.image = UIImage(
			systemName: icon,
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		nav.tabBarItem.title = title
		nav.navigationBar.prefersLargeTitles = true
		return nav
	}
	
	private func makeTransfersList() -> UIViewController {
		let sent = makeSentTransfersList()
		sent.navigationItem.title = "Sent"
		sent.navigationItem.largeTitleDisplayMode = .always
		
		let received = makeReceivedTransfersList()
		received.navigationItem.title = "Received"
		received.navigationItem.largeTitleDisplayMode = .always
		
		let vc = SegmentNavigationViewController(first: sent, second: received)
		vc.tabBarItem.image = UIImage(
			systemName: "arrow.left.arrow.right",
			withConfiguration: UIImage.SymbolConfiguration(scale: .large)
		)
		vc.title = "Transfers"
		vc.navigationBar.prefersLargeTitles = true
		return vc
	}
	
	private func makeFriendsList() -> ListViewController {
		let vc = ListViewController()
		vc.fromFriendsScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 2
        vc.title = "Friends"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(vc.addFriend))
        let isPremium =  User.shared?.isPremium == true
        vc.service = FriendsItemsServiceAdapter(
            api: FriendsAPI.shared,
            cache: isPremium ? friendsCache : NullFriendsCache(),
            selection: { [weak vc] friend in
            vc?.select(friend: friend)}
        )
		return vc
	}
	
	private func makeSentTransfersList() -> ListViewController {
		let vc = ListViewController()
		vc.fromSentTransfersScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 1
        vc.longDateStyle = true

        vc.navigationItem.title = "Sent"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Send", style: .done, target: vc, action: #selector(vc.sendMoney))
        vc.service = TransfersServiceAdapter(
            api: CardAPI.shared,
            selection: { [weak vc] transfer in
                vc?.select(transfer: transfer)
            },
            fromSentTransfersScreen: true)
		return vc
	}
	
	private func makeReceivedTransfersList() -> ListViewController {
		let vc = ListViewController()
		vc.fromReceivedTransfersScreen = true
        vc.shouldRetry = true
        vc.maxRetryCount = 1
        vc.longDateStyle = false
        
        vc.navigationItem.title = "Received"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Request", style: .done, target: vc, action: #selector(vc.requestMoney))
        vc.service = TransfersServiceAdapter(
            api: CardAPI.shared,
            selection: { [weak vc] transfer in
                vc?.select(transfer: transfer)
            },
            fromSentTransfersScreen: false)
		return vc
	}
	
	private func makeCardsList() -> ListViewController {
		let vc = ListViewController()
		vc.fromCardsScreen = true
        vc.shouldRetry = false
        vc.title = "Cards"
        vc.navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .add, target: vc, action: #selector(vc.addCard))
        vc.service = CardsItemsServiceAdapter(
            api: CardAPI.shared,
            selection: { [weak vc] card in
            vc?.select(card: card)}
        )
        
		return vc
	}
	
}


struct FriendsItemsServiceAdapter: ItemsService{
    let api: FriendsAPI
    let cache: FriendsCache
    let selection: (Friend)->Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadFriends { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map{ friends in
                    cache.save(friends)
                    return friends.map{ friend in
                        return ItemViewModel(friend: friend, selection: {selection(friend)})
                    }
                })
            }
        }
    }
}

struct CardsItemsServiceAdapter: ItemsService{
    let api: CardAPI
    let selection: (Card)->Void
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        api.loadCards {  result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map{ cards in
                    return cards.map { card in
                        ItemViewModel(card: card, selection: {selection(card)})
                    }
                })
            }
        }
    }
}

struct TransfersServiceAdapter: ItemsService{
    let api: CardAPI
    let selection: (Transfer)->Void
    let fromSentTransfersScreen: Bool
    
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void) {
        TransfersAPI.shared.loadTransfers { result in
            DispatchQueue.mainAsyncIfNeeded {
                completion(result.map { transfers in
                    transfers
                        .filter{ fromSentTransfersScreen ? $0.isSender : !$0.isSender }
                        .map{ transfer in
                            return ItemViewModel(transfer: transfer, longDateStyle: fromSentTransfersScreen , selection: { selection(transfer)})
                        }
                })
            }
        }
    }
}

//Null object pattern
class NullFriendsCache: FriendsCache {
    override func save(_ newFriends: [Friend]) {
    }
}

