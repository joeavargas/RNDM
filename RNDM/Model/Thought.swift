//
//  Thought.swift
//  RNDM
//
//  Created by Joe Vargas on 5/27/19.
//  Copyright © 2019 Joe Vargas. All rights reserved.
//

import Foundation
import Firebase

class Thought  {
    private(set) var username: String!
    private(set) var timestamp: Timestamp!
    private(set) var thoughtTxt: String!
    private(set) var numLikes: Int!
    private(set) var numComments: Int!
    private(set) var documentId: String!
    private(set) var userId: String!
    
    init(username: String, timestamp: Timestamp, thoughtTxt: String, numLikes: Int, numComments: Int, documentId: String, userId: String) {
        
        self.username = username
        self.timestamp = timestamp
        self.thoughtTxt = thoughtTxt
        self.numLikes = numLikes
        self.numComments = numComments
        self.documentId = documentId
        self.userId = userId
    }
    
    /* Rather than repetitive parsing from Firestore in MainVC, the below function was created here to parse data initially on app loadup by way of setListener(line 74). The setListener function handles two events: 1)Listens to the segment controller and sorts data accordingly and 2) Listens to the store for additions */
    
    class func parseData(snapshot: QuerySnapshot?) -> [Thought]{
        var thoughts = [Thought]()
        guard let snap = snapshot else {return thoughts}
        // the online packaged data to local 'data' package variable
        for document in snap.documents {
            let data = document.data()
            // conforms to the local 'data' package naming them similar to the Thought model variables...
            let username = data[USERNAME] as? String ?? "Anonymous"
            let timestamp: Timestamp = data[TIMESTAMP] as! Timestamp
            let date: Date = timestamp.dateValue()
            let thoughtTxt = data[THOUGHT_TXT] as? String ?? ""
            let numLikes = data[NUM_LIKES] as? Int ?? 0
            let numComments = data[NUM_COMMENTS] as? Int ?? 0
            let documentId = document.documentID
            let userId = data[USER_ID] as? String ?? ""
            
            //we can easily conform them to a Thought model variable of 'newThought' and then...
            let newThought = Thought(username: username, timestamp: timestamp, thoughtTxt: thoughtTxt, numLikes: numLikes, numComments: numComments, documentId: documentId, userId: userId)
            
            // append it to the tableview
            thoughts.append(newThought)
        }
        
        return thoughts
        
    }
}
