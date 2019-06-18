//
//  ThoughtCell.swift
//  RNDM
//
//  Created by Joe Vargas on 5/27/19.
//  Copyright © 2019 Joe Vargas. All rights reserved.
//

import UIKit
import Firebase

protocol ThoughtDelegate {
    func thoughtOptionsTapped(thought: Thought)
}


class ThoughtCell: UITableViewCell {

    //Outlets
    
    @IBOutlet weak var usernameLbl: UILabel!
    @IBOutlet weak var timestampLbl: UILabel!
    @IBOutlet weak var thoughtTxtLbl: UILabel!
    @IBOutlet weak var likesImg: UIImageView!
    @IBOutlet weak var likesNumLbl: UILabel!
    @IBOutlet weak var commentsNumLabel: UILabel!
    
    @IBOutlet weak var optionsMenu: UIImageView!
    
    //Variables
    private var thought: Thought!
    private var delegate: ThoughtDelegate?
       
    
    override func awakeFromNib() {
        super.awakeFromNib()
        let  tap = UITapGestureRecognizer(target: self, action: #selector(likeTapped))
        likesImg.addGestureRecognizer(tap)
        likesImg.isUserInteractionEnabled = true
    }
    
    @objc func likeTapped(){
        Firestore.firestore().collection(THOUGHTS_REF).document(thought.documentId)
        .setData([NUM_LIKES : thought.numLikes + 1], merge: true)
    }
    
    func configureCell(thought: Thought, delegate: ThoughtDelegate?){
        optionsMenu.isHidden = true
        self.thought = thought
        self.delegate = delegate
        usernameLbl.text = thought.username
        thoughtTxtLbl.text = thought.thoughtTxt
        likesNumLbl.text = String(thought.numLikes)
        commentsNumLabel.text = String(thought.numComments)
        
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMM d, HH:mm"
        let timestamp = formatter.string(from: thought.timestamp.dateValue())
        timestampLbl.text = timestamp
        
        //If the user id who created the post is the same as the user who's logged in, unhide the ellipse button and make it interactable
        if thought.userId == Auth.auth().currentUser?.uid {
            optionsMenu.isHidden = false
            optionsMenu.isUserInteractionEnabled = true
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(thoughtOptionsTapped))
            optionsMenu.addGestureRecognizer(tap)
        }
        
    }

    
    @objc func thoughtOptionsTapped(){
        delegate?.thoughtOptionsTapped(thought: thought)
    }
    
    
}

