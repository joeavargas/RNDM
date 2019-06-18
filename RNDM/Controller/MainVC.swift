//
//  ViewController.swift
//  RNDM
//
//  Created by Joe Vargas on 5/27/19.
//  Copyright © 2019 Joe Vargas. All rights reserved.
//

import UIKit
import Firebase

enum ThoughtCategory : String {
    case serious = "serious"
    case funny = "funny"
    case crazy = "crazy"
    case popular = "popular"
}

class MainVC: UIViewController, UITableViewDataSource, UITableViewDelegate, ThoughtDelegate {
    
    //Outlets
    @IBOutlet private weak var segmentControl: UISegmentedControl!
    @IBOutlet private weak var tableView: UITableView!
    
    //Variables
    private var thoughts = [Thought]()
    private var thoughtsCollectionRef: CollectionReference!
    private var thoughtsListener: ListenerRegistration!
    private var selectedCategory = ThoughtCategory.funny.rawValue
    private var handle: AuthStateDidChangeListenerHandle?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.dataSource = self
        tableView.delegate = self
        tableView.estimatedRowHeight = 80
        tableView.rowHeight = UITableView.automaticDimension
        
        thoughtsCollectionRef = Firestore.firestore().collection(THOUGHTS_REF)
    }
    
    //Let's check to see if the user is logged in then query the data from Firestore and continue to listen to the database in order to keep the TableView up to date...
    override func viewWillAppear(_ animated: Bool) {
        handle = Auth.auth().addStateDidChangeListener({ (auth, user) in
            // if user is not logged in, present loginVC
            if user == nil {
                let storyboard = UIStoryboard(name: "Main", bundle: nil)
                let loginVC = storyboard.instantiateViewController(withIdentifier: "loginVC")
                self.present(loginVC, animated: true, completion: nil)
                
            //but if user is logged in just start the listener
            } else {
                self.setListener()
            }
        })
}
    
    //This will stop listening to Firestore when segueing away to conserve network resources
    override func viewWillDisappear(_ animated: Bool) {
        if thoughtsListener != nil{
            thoughtsListener.remove()
        }
        
        

    }
    
    func thoughtOptionsTapped(thought: Thought) {
        //This is where we create the alert to handle the deletion
        let alert = UIAlertController(title: "Delete", message: "Do you want to delete your thought?", preferredStyle: .actionSheet)
        let deleteAction = UIAlertAction(title: "Delete Thought", style: .default) { (action) in
            //Delete Thought
            
            self.delete(collection: Firestore.firestore().collection(THOUGHTS_REF).document(thought.documentId).collection(COMMENTS_REF), completion: { (error) in
                if let error = error{
                    debugPrint("Could not delete thought: \(error.localizedDescription)")
                } else {
                    Firestore.firestore().collection(THOUGHTS_REF).document(thought.documentId).delete(completion: { (error) in
                        if let error = error{
                            debugPrint("Could not delete thought: \(error.localizedDescription)")
                        } else {
                            alert.dismiss(animated: true, completion: nil)
                        }
                    })
                    
                }
            })
        }
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        alert.addAction(deleteAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
        
    }
    
    func delete(collection: CollectionReference, batchSize: Int = 100, completion: @escaping (Error?) -> ()) {
        
        collection.limit(to: batchSize).getDocuments { (docset, error) in
            guard let docset = docset else {
                completion(error)
                return
            }
            guard docset.count > 0 else {
                completion(nil)
                return
            }
            let batch = collection.firestore.batch()
            
            docset.documents.forEach {batch.deleteDocument($0.reference)}

            batch.commit { (batchError) in
                if let batchError = batchError {
                    completion(batchError)
                } else {
                    self.delete(collection: collection, batchSize: batchSize, completion: completion)
                }
            }
        }
    }
    
    @IBAction func categoryChanged(_ sender: Any) {
        switch segmentControl.selectedSegmentIndex {
        case 0:
            selectedCategory = ThoughtCategory.funny.rawValue
        case 1:
            selectedCategory = ThoughtCategory.serious.rawValue
        case 2:
            selectedCategory = ThoughtCategory.crazy.rawValue
        default:
            selectedCategory = ThoughtCategory.popular.rawValue
        }
        
        thoughtsListener.remove()
        setListener()
    }
    
    @IBAction func logOutBtnTapped(_ sender: Any) {
        //Firebase requires a do-try-catch for signing out
        let firebaseAuth = Auth.auth()
        do{
            try firebaseAuth.signOut()
        } catch let signoutError as NSError {
            debugPrint("Error signing out: \(signoutError)")
        }
    }
    

    func setListener(){
        //When "popular" is selected in the segment controller, listener queries the data by popularity looking at the 'numLikes' value in each document and sorts it in decending order of popularity
        if selectedCategory == ThoughtCategory.popular.rawValue {
            thoughtsListener = thoughtsCollectionRef
                .order(by: NUM_LIKES, descending: true)
                .addSnapshotListener { (snapshot, error) in
                    if let err = error{
                        debugPrint("Error fetching docs: \(err)")
                    } else {
                        self.thoughts.removeAll()//Removes all the current data from the view so a fresh update can take its place soon after
                        self.thoughts = Thought.parseData(snapshot: snapshot) //grabs a local state of Firestore - see Thought.swift for details
                        self.tableView.reloadData() //reloads the tableview to see the latest state in Firestore
                    }
            }
        } else {
            thoughtsListener = thoughtsCollectionRef
                .whereField(CATEGORY, isEqualTo: selectedCategory)
                .order(by: TIMESTAMP, descending: true)
                .addSnapshotListener { (snapshot, error) in
                    // if there is an error getting the documents, print the error...
                    if let err = error{
                        debugPrint("Error fetching docs: \(err)")
                    } else {
                        self.thoughts.removeAll()//Removes all the current data from the view so a fresh update can take its place soon after
                        guard let snap = snapshot else {return}
                        // initialize the online packaged data to local 'data' package variable
                        for document in snap.documents {
                            let data = document.data()
                            // conforms the local 'data' package naming them similar to the Thought model variables...
                            let username = data[USERNAME] as? String ?? "Anonymous"
                            let timestamp = data[TIMESTAMP] as? Timestamp ?? Timestamp.init(date: Date())
//                            let date: Date = timestamp.dateValue()
//                            let timestamp = data[TIMESTAMP] as? Date ?? Date()
                            let thoughtTxt = data[THOUGHT_TXT] as? String ?? ""
                            let numLikes = data[NUM_LIKES] as? Int ?? 0
                            let numComments = data[NUM_COMMENTS] as? Int ?? 0
                            let documentId = document.documentID
                            let USER_ID = Auth.auth().currentUser?.uid ?? ""
                            
                            // it can easily conform them to a Thought model variable of 'newThought' and then...
                            let newThought = Thought(username: username, timestamp: timestamp, thoughtTxt: thoughtTxt, numLikes: numLikes, numComments: numComments, documentId: documentId, userId: USER_ID)
                            
                            // append it to the tableview
                            self.thoughts.append(newThought)
                        }
                        //reload the tableview to see the latest data in Firestore
                        self.tableView.reloadData()
                    }
            }
        }
    }

    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return thoughts.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "thoughtCell", for: indexPath) as? ThoughtCell {

            cell.configureCell(thought: thoughts[indexPath.row], delegate: self)

            return cell
        } else {
            return UITableViewCell()
        }
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        performSegue(withIdentifier: "toComments", sender: thoughts[indexPath.row])
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "toComments" {
            if let destinationVC = segue.destination as? CommentsVC{
                if let thought = sender as? Thought {
                    destinationVC.thought = thought
                }
            }
        }
    }
    
}

