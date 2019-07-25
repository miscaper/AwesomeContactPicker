//
//  ContactsViewController.swift
//  AwesomeContactPicker
//
//  Created by Michael Guo on 7/21/19.
//

import UIKit
import Contacts

class ContactsViewController: UIViewController {
    
    @IBOutlet weak var topContainerView: UIView!
    @IBOutlet weak var searchTextField: UITextField!
    @IBOutlet weak var tableView: UITableView!
    
    let contactStore = CNContactStore()
    let contactCellReuseID = "ContactCellReuseID"
    var contacts = [CNContact]()
    var displayContacts = [DisplayContact]()
    var filteredContacts = [DisplayContact]()
    var selectedContacts: Set<String> = []
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        setupNavBarItems()
        setupSearchTextField()
        setupTableView()
        fetchContacts()
    }
    
    func setupNavBarItems() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(title: "Cancel", style: .plain, target: self, action: #selector(didTapCancel(_:)))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Done", style: .done, target: self, action: #selector(didTapDone(_:)))
    }
    
    func setupSearchTextField() {
        searchTextField.addTarget(self, action: #selector(searchTextFieldDidChanged(_:)), for: .editingChanged)
        searchTextField.layer.shadowPath =
            UIBezierPath(roundedRect: searchTextField.bounds,
                         cornerRadius: searchTextField.layer.cornerRadius).cgPath
        searchTextField.layer.shadowColor = UIColor(white: 200/255.0, alpha: 0.5).cgColor
        searchTextField.layer.shadowOpacity = 0.5
        searchTextField.layer.shadowOffset = CGSize(width: 0, height: 1)
        searchTextField.layer.shadowRadius = 2
        searchTextField.layer.masksToBounds = false
    }
    
    func setupTableView() {
        tableView.register(ResourceHelper.contactNib(), forCellReuseIdentifier: contactCellReuseID)
        tableView.delegate = self
        tableView.dataSource = self
    }
    
    func fetchContacts() {
        contactStore.requestAccess(for: .contacts) { [weak self] (success, error) in
            if !success || error != nil {
                print("Unable to fetch contacts: \(error?.localizedDescription ?? "Unknown")")
            }
            
            DispatchQueue.global(qos: .background).async {
                if let strongSelf = self {
                    let keys = [CNContactIdentifierKey,
                                CNContactGivenNameKey,
                                CNContactMiddleNameKey,
                                CNContactFamilyNameKey,
                                CNContactThumbnailImageDataKey] as [CNKeyDescriptor]
                    let request = CNContactFetchRequest(keysToFetch: keys)
                    request.sortOrder = CNContactSortOrder.familyName
                    
                    do {
                        try strongSelf.contactStore.enumerateContacts(with: request, usingBlock: { (contact, stop) in
                            strongSelf.contacts.append(contact)
                            
                            let displayContact = DisplayContact(identifier: contact.identifier, givenName: contact.givenName, middleName: contact.middleName, familyName: contact.familyName, thumnailData: contact.thumbnailImageData)
                            strongSelf.displayContacts.append(displayContact)
                        })
                        strongSelf.filteredContacts = strongSelf.displayContacts
                        DispatchQueue.main.async {
                            strongSelf.tableView.reloadData()
                        }
                    } catch {
                        print("Unable to fetch contacts")
                    }
                }
            }
        }
    }
}

// MARK: Nav Actions
extension ContactsViewController {
    @objc func didTapCancel(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true, completion: nil)
    }
    
    @objc func didTapDone(_ sender: UIBarButtonItem) {
        navigationController?.dismiss(animated: true, completion: {
            // TODO: pass selected contacts back to the client
        })
    }
}

// MARK: SearchTextField
extension ContactsViewController {
    @objc func searchTextFieldDidChanged(_ sender: UITextField) {
        let query = sender.text ?? ""
        if query == "" {
            filteredContacts = displayContacts
        } else {
            filteredContacts = displayContacts.filter({ $0.fullName.lowercased().contains(query.lowercased()) })
        }
        tableView.reloadData()
    }
}

extension ContactsViewController: UITableViewDataSource {
    
    func tableView(_ tableView: UITableView, heightForRowAt indexPath: IndexPath) -> CGFloat {
        return 40
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return filteredContacts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        if let cell = tableView.dequeueReusableCell(withIdentifier: contactCellReuseID, for: indexPath) as? ContactTableViewCell {
            cell.displayContact = filteredContacts[indexPath.row]
            return cell
        }
        return UITableViewCell()
    }
    
}

extension ContactsViewController: UITableViewDelegate {
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let contactID = filteredContacts[indexPath.row].identifier
        selectedContacts.insert(contactID)
    }
    
    func tableView(_ tableView: UITableView, didDeselectRowAt indexPath: IndexPath) {
        let contactID = filteredContacts[indexPath.row].identifier
        selectedContacts.remove(contactID)
    }
    
    func tableView(_ tableView: UITableView, willDisplay cell: UITableViewCell, forRowAt indexPath: IndexPath) {
        cell.setSelected(selectedContacts.contains(filteredContacts[indexPath.row].identifier), animated: false)
    }
}

struct DisplayContact {
    var identifier: String
    var givenName: String
    var middleName: String
    var familyName: String
    var thumnailData: Data?
    var fullName: String {
        get {
            let names = [givenName, middleName, familyName]
            return names.filter({ (name) -> Bool in
                return name != ""
            }).joined(separator: " ")
        }
    }
}
