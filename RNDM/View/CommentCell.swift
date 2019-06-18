//
//  CommentsCell.swift
//  RNDM
//
//  Created by Joe Vargas on 5/30/19.
//  Copyright © 2019 Joe Vargas. All rights reserved.
//

import UIKit
import Firebase

protocol CommentDelegate {
    func commentsOptionsTapped(comment: Comment)
}

class CommentCell: UITableViewCell {
    
    //Outlets
    
    @IBOutlet weak var usernameTxt: UILabel!
    @IBOutlet weak var timestampTxt: UILabel!
    @IBOutlet weak var commentTxt: UILabel!
    @IBOutlet weak var optionsMenu: UIImageView!
    
    //Variables
    private var comment: Comment!
    private var delegate: CommentDelegate?
    
    
    func configureCell(comment: Comment, delegate: CommentDelegate?) {
        usernameTxt.text = comment.username
        commentTxt.text = comment.commentTxt
        optionsMenu.isHidden = true
        self.comment = comment
        self.delegate = delegate
        
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d, hh:mm"
        let timestamp = formatter.string(from: comment.timestamp)
        timestampTxt.text = timestamp
        
        if comment.userId == Auth.auth().currentUser?.uid {
            optionsMenu.isHidden = false
            optionsMenu.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(commentOptionsTapped))
            optionsMenu.addGestureRecognizer(tap)
        }
    }
    
    @objc func commentOptionsTapped(){
        delegate?.commentsOptionsTapped(comment: comment)
    }


}
