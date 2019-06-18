//
//  CommentsVC.swift
//  RNDM
//
//  Created by Joe Vargas on 5/30/19.
//  Copyright © 2019 Joe Vargas. All rights reserved.
//

import UIKit
import Firebase

class CommentsVC: UIViewController, UITableViewDelegate, UITableViewDataSource, CommentDelegate {
    
    
    
    //Outlets
    
    @IBOutlet weak var tableView: UITableView!
    @IBOutlet weak var addCommentTxt: UITextField!
    @IBOutlet weak var keyboardView: UIView!
    
    //Variables
    var thought: Thought!
    var comments = [Comment]()
    var thoughtRef: DocumentReference!
    let firestore = Firestore.firestore()
    var username: String!
    var commentListener: ListenerRegistration!

    override func viewDidLoad() {
        super.viewDidLoad()
        tableView.delegate = self
        tableView.dataSource = self
        thoughtRef = firestore.collection(THOUGHTS_REF).document(thought.documentId)
        if let name = Auth.auth().currentUser?.displayName{
            username = name
        }
        self.view.bindToKeyboard()
    }
    override func viewDidAppear(_ animated: Bool) {
        commentListener = firestore.collection(THOUGHTS_REF).document(self.thought.documentId)
            .collection(COMMENTS_REF)
            .order(by: TIMESTAMP, descending: false)
            .addSnapshotListener({ (snapshot, error) in
                
                guard let snapshot = snapshot else {
                    debugPrint("Error fetching comments: \(error!)")
                    return
                }
                self.comments.removeAll()
                self.comments = Comment.parseData(snapshot: snapshot)
                self.tableView.reloadData()
            })
    }
    
    func commentsOptionsTapped(comment: Comment) {
        let alert = UIAlertController(title: "Edit Comment", message: "You can delete or edit", preferredStyle: .actionSheet)
        
        let deleteAction = UIAlertAction(title: "Delete Comment", style: .default) { (action) in
            //delete comment
//            self.firestore.collection(THOUGHTS_REF).document(self.thought.documentId).collection(COMMENTS_REF).document(comment.documentId).delete(completion: { (error) in
//                if let error = error {
//                    debugPrint("Unable to delete comment: \(error.localizedDescription)")
//                } else {
//                    
//                    //dismiss alert
//                    alert.dismiss(animated: true, completion: nil)
//                }
//            })
            self.firestore.runTransaction({ (transaction, error) -> Any? in
                
                //declare a variable for a snapshot read of the current thoughts in the database...
                let thoughtDocument: DocumentSnapshot
                do {
                    //Pass in the path to the thought document for which you're going to add a comment document to...
                    try thoughtDocument = transaction.getDocument(Firestore.firestore()
                        .collection(THOUGHTS_REF).document(self.thought.documentId))
                } catch let error as NSError {
                    //if there is an error fetching the thought document, debug print the error...
                    debugPrint("Fetch error: \(error.localizedDescription)")
                    return nil
                }
                
                //drill down to the comments collection, grabbing the number of comments and returning the Int(number of) comments to increment by one later...
                guard let oldNumComments = thoughtDocument.data()![NUM_COMMENTS] as? Int else { return nil }
                
                //update the current data in the NUM_COMMENTS field, increasing it by one using the logic of the previous oldNumComments + 1.
                transaction.updateData([NUM_COMMENTS : oldNumComments - 1], forDocument: self.thoughtRef)
                
                let commentRef = self.firestore.collection(THOUGHTS_REF).document(self.thought.documentId).collection(COMMENTS_REF).document(comment.documentId)
                
                transaction.deleteDocument(commentRef)
                
                //Returning nothing from the transaction result...
                return nil
            }) { (object, error) in
                
                //handle any errors if there is one
                if let error = error {
                    debugPrint("Transaction failed: \(error)")
                } else {
                    
                    alert.dismiss(animated: true, completion: nil)

                }
            }
        }
        let editAction = UIAlertAction(title: "Edit Comment", style: .default) { (action) in
            //edit comment
            self.performSegue(withIdentifier: "toEditComment", sender: (comment, self.thought))
            alert.dismiss(animated: true, completion: nil)
        }
        
        let cancelAction = UIAlertAction(title: "Cancel", style: .cancel, handler: nil)
        
        alert.addAction(deleteAction)
        alert.addAction(editAction)
        alert.addAction(cancelAction)
        present(alert, animated: true, completion: nil)
    }
    
    override func viewDidDisappear(_ animated: Bool) {
        commentListener.remove()
    }
    
    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if let destination = segue.destination as? UpdateCommentVC{
            if let commentData = sender as? (comment: Comment, thought: Thought){
                destination.commentData = commentData
            }
        }
    }

    @IBAction func addCommentTapped(_ sender: Any) {
        guard let commentTxt = addCommentTxt.text else {return}
        
        // Here is a Firestore Transaction which is used when you have multiple reads and writes. In a trasaction, you have to read first(do-catch block), then write.
        
        firestore.runTransaction({ (transaction, error) -> Any? in
            
            //declare a variable for a snapshot read of the current thoughts in the database...
            let thoughtDocument: DocumentSnapshot
            do {
                //Pass in the path to the thought document for which you're going to add a comment document to...
                try thoughtDocument = transaction.getDocument(Firestore.firestore()
                    .collection(THOUGHTS_REF).document(self.thought.documentId))
            } catch let error as NSError {
                //if there is an error fetching the thought document, debug print the error...
                debugPrint("Fetch error: \(error.localizedDescription)")
                return nil
            }
            
            //drill down to the comments collection, grabbing the number of comments and returning the Int(number of) comments to increment by one later...
            guard let oldNumComments = thoughtDocument.data()![NUM_COMMENTS] as? Int else { return nil }
            
            //update the current data in the NUM_COMMENTS field, increasing it by one using the logic of the previous oldNumComments + 1.
            transaction.updateData([NUM_COMMENTS : oldNumComments + 1], forDocument: self.thoughtRef)
            /*
            Example:
            If the oldNumComments returns an Int of 3
            The transaction will run when a new comment is added: oldNumComments + 1 = 4
            You'll have an Int of 4 after this logic is ran
            If a new comment is added again: oldNumComments(value of 4) + 1
             ...oldNumComments will now be 5 and so on and so forth.
            */
            
            //create a reference to the comment document so we can genereate an auto id
            let newCommentRef = self.firestore.collection(THOUGHTS_REF).document(self.thought.documentId).collection(COMMENTS_REF).document()
            
            //create the new document here with the data you're wanting to pass into the new document
            transaction.setData([
                COMMENT_TXT : commentTxt,
                TIMESTAMP : FieldValue.serverTimestamp(),
                USERNAME : self.username as Any,
                USER_ID : Auth.auth().currentUser?.uid ?? ""
                ], forDocument: newCommentRef)
            
            //Returning nothing from the transaction result...
            return nil
        }) { (object, error) in
            
            //handle any errors if there is one
            
            if let error = error {
                debugPrint("Transaction failed: \(error)")
            } else {
                
                //after adding the new comment document, reset the addCommentTxt field to blank to be ready for a new comment to enter
                self.addCommentTxt.text = ""
                //then hide the keyboard
                self.addCommentTxt.resignFirstResponder()
            }
        }
        
    }
    
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return comments.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        if let cell = tableView.dequeueReusableCell(withIdentifier: "commentCell", for: indexPath) as? CommentCell{
            
            cell.configureCell(comment: comments[indexPath.row], delegate: self)
            return cell
            
        }
        
        
        return UITableViewCell()
    }
    
    
    
    
    
    
    
    
    
    
    
    
}
