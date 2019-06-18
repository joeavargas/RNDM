//
//  Comment.swift
//  RNDM
//
//  Created by Joe Vargas on 5/30/19.
//  Copyright © 2019 Joe Vargas. All rights reserved.
//

import Foundation
import Firebase

class Comment {
    
    private(set) var username: String!
    private(set) var timestamp: Date!
    private(set) var commentTxt: String!
    private(set) var documentId: String!
    private(set) var userId: String!
    
    init(username: String, timestamp: Date, commentTxt: String, documentId: String, userId: String) {
        
        self.username = username
        self.timestamp = timestamp
        self.commentTxt = commentTxt
        self.documentId = documentId
        self.userId = userId
    }
    
    /* Rather than repetitive parsing from Firestore in MainVC, the below function was created here to parse data initially on app loadup by way of setListener(line 74). The setListener function handles two events: 1)Listens to the segment controller and sorts data accordingly and 2) Listens to the store for additions */
    
    class func parseData(snapshot: QuerySnapshot?) -> [Comment]{
        var comments = [Comment]()
        
        guard let snap = snapshot else {return comments }
        // the online packaged data to local 'data' package variable
        for document in snap.documents {
            let data = document.data()
            // conforms to the local 'data' package naming them similar to the Thought model variables...
            let username = data[USERNAME] as? String ?? "Anonymous"
            let timestamp: Timestamp = data[TIMESTAMP] as! Timestamp
            let date: Date = timestamp.dateValue()
            let commentTxt = data[COMMENT_TXT ] as? String ?? ""
            let documentId = document.documentID
            let userId = data[USER_ID] as? String ?? ""

            //we can easily conform them to a Thought model variable of 'newThought' and then...
            let newComment = Comment(username: username, timestamp: date, commentTxt: commentTxt, documentId: documentId, userId: userId)

            // append it to the tableview
            comments.append(newComment)
        }
        return comments
        
    }
}
