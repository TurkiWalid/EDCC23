//
// Copyright © Essential Developer. All rights reserved.
//

import UIKit

protocol ItemsService {
    func loadItems(completion: @escaping (Result<[ItemViewModel], Error>) -> Void)
}

class ListViewController: UITableViewController {
	var items = [ItemViewModel]()
	
    var service: ItemsService?
    
	var retryCount = 0
	var maxRetryCount = 0
	var shouldRetry = false
	
	var longDateStyle = false
	
	var fromReceivedTransfersScreen = false
	var fromSentTransfersScreen = false
	var fromCardsScreen = false
	var fromFriendsScreen = false
	
	override func viewDidLoad() {
		super.viewDidLoad()
		refreshControl = UIRefreshControl()
		refreshControl?.addTarget(self, action: #selector(refresh), for: .valueChanged)
	}
	
	override func viewWillAppear(_ animated: Bool) {
		super.viewWillAppear(animated)
		
		if tableView.numberOfRows(inSection: 0) == 0 {
			refresh()
		}
	}
	
	@objc private func refresh() {
		refreshControl?.beginRefreshing()
        service?.loadItems(completion: handleAPIResult)
	}
    
    private func handleAPIResult(_ result: Result<[ItemViewModel], Error>) {
        switch result {
        case let .success(items):
            self.retryCount = 0
            self.items = items
            self.refreshControl?.endRefreshing()
            self.tableView.reloadData()
        case let .failure(error):
            if fromFriendsScreen && User.shared?.isPremium == true && retryCount == maxRetryCount {
                (UIApplication.shared.connectedScenes.first?.delegate as! SceneDelegate).cache.loadFriends { [weak self] result in
                    DispatchQueue.mainAsyncIfNeeded {
                        switch result {
                        case let .success(friends):
                            self?.items = friends.map{ friend in
                                return ItemViewModel(friend: friend, selection: { [weak self] in self?.select(friend: friend)})
                            }
                            self?.tableView.reloadData()
                            
                        case let .failure(error):
                            self?.showError(error)
                        }
                        self?.refreshControl?.endRefreshing()
                    }
                }
            }else {
                self.processFailure(error)
            }
        }
    }
    
    private func processFailure(_ error: Error) {
        if shouldRetry && retryCount < maxRetryCount {
            retryCount += 1
            refresh()
            return
        }
        retryCount = 0
        self.refreshControl?.endRefreshing()
        showError(error)
    }
	
    private func showError(_ error: Error){
        let alert = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "Ok", style: .default))
        showDetailViewController(alert, sender: self)
    }
    
	override func numberOfSections(in tableView: UITableView) -> Int {
		1
	}
	
	override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
		items.count
	}
	
	override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
		let item = items[indexPath.row]
		let cell = tableView.dequeueReusableCell(withIdentifier: "ItemCell") ?? UITableViewCell(style: .subtitle, reuseIdentifier: "ItemCell")
		cell.configure(item)
		return cell
	}
	
	override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
		let item = items[indexPath.row]
        item.selection()
	}
	
	@objc func addCard() {
        show(AddCardViewController(), sender: self)
	}
	
	@objc func addFriend() {
        show(AddFriendViewController(), sender: self)
	}
	
	@objc func sendMoney() {
		show(SendMoneyViewController(), sender: self)
	}
	
	@objc func requestMoney() {
		show(RequestMoneyViewController(), sender: self)
	}
}

struct ItemViewModel {
    var labelText: String
    var detailText: String
    var selection: ()->Void
    
    init(friend: Friend, selection: @escaping () -> Void) {
        labelText = friend.name
        detailText = friend.phone
        self.selection = selection
    }
    
    init(card: Card, selection: @escaping () -> Void){
        labelText = card.number
        detailText = card.holder
        self.selection = selection
    }
    
    init(transfer: Transfer, longDateStyle: Bool, selection: @escaping () -> Void) {
        let numberFormatter = Formatters.number
        numberFormatter.numberStyle = .currency
        numberFormatter.currencyCode = transfer.currencyCode
        
        let amount = numberFormatter.string(from: transfer.amount as NSNumber)!
        labelText = "\(amount) • \(transfer.description)"
        
        let dateFormatter = Formatters.date
        if longDateStyle {
            dateFormatter.dateStyle = .long
            dateFormatter.timeStyle = .short
            detailText = "Sent to: \(transfer.recipient) on \(dateFormatter.string(from: transfer.date))"
        } else {
            dateFormatter.dateStyle = .short
            dateFormatter.timeStyle = .short
            detailText = "Received from: \(transfer.sender) on \(dateFormatter.string(from: transfer.date))"
        }
        self.selection = selection
    }
}


extension UIViewController {
    func select(friend: Friend ){
        let vc = FriendDetailsViewController()
        vc.friend = friend
        self.show(vc, sender: self)
    }
    
    func select(card: Card){
        let vc = CardDetailsViewController()
        vc.card = card
        self.show(vc, sender: self)
    }
    
    func select(transfer: Transfer){
        let vc = TransferDetailsViewController()
        vc.transfer = transfer
        self.show(vc, sender: self)
    }
}


extension UITableViewCell {
    func configure(_ itemVm: ItemViewModel) {
        textLabel?.text = itemVm.labelText
        detailTextLabel?.text = itemVm.detailText
    }
}
