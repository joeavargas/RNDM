![alt text](https://github.com/joeavargas/RNDM/blob/master/demo/firebase_ios.png "Firebase + iOS")

# RNDM

RNDM is an iOS app with a serverless backend that requires authentication and set rules to create, read, write, update and delete data.

# Libraries used:
* Xcode 10.2.1 / Swift 5
* Google Firebase with Cloud Firestore database

# About:
RNDM is an app that allows users to post random thoughts in three categories: *Funny*, *Serious* and *Crazy*. RNDM allows users to see each other’s posts and using some if/else logic, users can interact with posts such as commenting on, editing and deleting posts and comments. 

RNDM uses Google Firebase’s email authentication to register and log-in users. When a user registers an account, a UID or Unique Identifier is created for them automatically. This UID follows the user as they post a thought and comment. Each thought and comment have a `uid` field with a value and the if/else logic looks at that value to determine who’s the owner. More on this later.

![alt text](https://github.com/joeavargas/RNDM/blob/master/demo/registering-and-logging-in.gif "Log In View Controller")

Once logged in, the user is greeted with a simple interface. In the navigation bar on top, you got two actions and a RNDM label. One action is labeled as a lightbulb with a + sign is to post a new thought: 

![alt text](https://github.com/joeavargas/RNDM/blob/master/demo/mainvc.png "Main View Controller")

Once the lightbulb tapped, it segues to a compose view where it has a text field and post button. The user can enter text in the textfield, tap on a category on top and tap the Post button when done. The Post button triggers the Firestore `.addDocument()` method where it stores the following key field values in a document:
* Category
* Number of Comments
* Number of Likes
* Thought messsage
* Username
* UID
* Timestamp

As you can see, the UID is stored as a value to reference to when performing logics which will later be explained in detail:

``` 
@IBAction func postBtnTapped(_ sender: Any) {
        Firestore.firestore().collection(THOUGHTS_REF).addDocument(data: [
            CATEGORY : selectedCategory,
            NUM_COMMENTS : 0,
            NUM_LIKES : 0,
            THOUGHT_TXT : thoughtTxt.text,
            TIMESTAMP : FieldValue.serverTimestamp(),
            USERNAME : Auth.auth().currentUser?.displayName ?? "",
            USER_ID : Auth.auth().currentUser?.uid ?? ""
        ]) { (err) in
            if let err = err{
                debugPrint("Error adding document: \(err)")
            } else {
                self.navigationController?.popViewController(animated: true)
            }
        }
    }
```

![alt text](https://github.com/joeavargas/RNDM/blob/master/demo/addthoughtvc.png "Add Thought View Controller")

The other action is the Logout button when tapped, it triggers the Firestore `.signOff()` method to sign out of the app. This is where it gets interesting. Firestore has a method called `.addStateDidChangeListener()` that is a like watch dog making sure the user is consistently authenticated. If you’re properly authenticated, you get to continue using the app accordingly. If it detects that you tapped on the Logout button, the app will direct you straight to the Log In view. This ensures a user’s data is kept private even when not authenticated in.

**Auth State Listener:**
```
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
```

Now let’s talk about the structure of the tableview cell that presents each user’s posted thought. The structure might look familiar to the one of Instagram. You’ve got the username, time stamp, like and comment count depicted by a yellow star and message bubble all of which is casted by the document data stored in Firestore after it was added when the Post button was tapped. However, what is up with the ellipses icon on the right and why do some posts have it and others don’t? Well friends, that is the authenticated user’s `uid` value working with some if/else logic in the background. The logic consists of *if the uid of the document(comment) is the same as the authenticated user’s uid, add the ellipses; else, do not add the ellipses.* Now, what makes the ellipses button so special is that it has the power to edit or delete a post and comment. This is why the if/else logic is important. You don’t want to delete another user’s content as well as you don’t want anyone deleting your content:

**Thought posts:**
```
if thought.userId == Auth.auth().currentUser?.uid {
            optionsMenu.isHidden = false
            optionsMenu.isUserInteractionEnabled = true
            
            let tap = UITapGestureRecognizer(target: self, action: #selector(thoughtOptionsTapped))
            optionsMenu.addGestureRecognizer(tap)
        }
```

**Comment posts:**
```
if comment.userId == Auth.auth().currentUser?.uid {
            optionsMenu.isHidden = false
            optionsMenu.isUserInteractionEnabled = true
            let tap = UITapGestureRecognizer(target: self, action: #selector(commentOptionsTapped))
            optionsMenu.addGestureRecognizer(tap)
        }
```

The edit method is quite simple. When you tap on the ellipses of a comment post, tap on *Edit Comment* option in the Action Sheet where the post is referenced by the `documentId` grabbing the `commentText` and casting the data over to the UpdateCommentVC where it’s editable in a textfield. You’ll also be presented with an Update button where it triggers the Firestore .updateData() function; the text in the textfield will replace what is already in Firestore once that Update button is pressed whether you add, remove or modify the text. Once the function finishes running, you’ll be presented back to the comment feed view.

The Firestore delete function can get very sophisticated. I say this because we can go two routes here. First route is like the update comment but instead of updating a comment, you want to delete it. So let’s drill down to the comment you want to delete by referencing the post documentId, find our way to the comments collection and finally landing on the comment itself by its documentId; initiate the Firestore `.delete()` function…POOF, comment gone. However, did we forget that we’re keeping score of the number of comments with that comment bubble? The above delete function will delete the comment – great - however, it will not decrease the comment count.  
So how do we calculate the comment count(`NUM_COMMENTS`)? Well Firestore has a function called `.runTransaction()` where it does two things in this explicit order. First, it reads the current state of the database. Second, it **writes**/**deletes**/**updates**. So let’s put this in an add and delete comment scenario. 

**Adding Comments:** Firestore is first read grabbing the number of comments in the current state and placing that value in a variable called `oldNumComments`. Then as a user is about to submit the comment, the `COMMENT_TXT`, `TIMESTAMP`, `USERNAME` and `USER_ID` are passed through the Firestore `.setDate()` function where it creates the comment. We’re not done yet – the Firestore function, .updateData(), is called grabbing the current value of `oldNumComments`, adding 1 and setting the result value to the `NUM_COMMENTS`: 

```
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
        })
```

**Deleting Comments:** Deleting a comment(document) is the same order as adding comments however, instead of using `.setData()` function, you use the `.deleteDocument()` function and where you add 1, you instead deduct 1: 
```
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
            })
```

I discussed about user uid and document uids and how they work together using code logic to allow users to interact with documents based on their uid and document uid. Below is a snippet of the Firestore database security rules along with annotations to explain their purpose:

![alt text](https://github.com/joeavargas/RNDM/blob/master/demo/firestore-sec-rules.png "Add Thought View Controller")

# RNDM Walkthrough on YouTube
See RNDM in action by clicking the YouTube link below. Thanks for watching!

<a href="http://www.youtube.com/watch?feature=player_embedded&v=w5OsqfEkD-U" target="_blank">
 <img src="http://img.youtube.com/vi/w5OsqfEkD-U/0.jpg" target="_blank" alt="RNDM" width="720" height="540" border="10" />
</a>
