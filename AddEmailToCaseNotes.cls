/*
        This trigger will take any new emails that are attached to a case
        and will create a case comment with the same information. This is 
        done to provide time based tracking for cases.
        
        Marc D. Behr
        03-November 2009
        
        Added code to extract only the latest reply from the message 19-May-2011
        
*/

trigger AddEmailToCaseNotes on EmailMessage (after insert) {

    List<CaseComment> NewComments = new List<CaseComment>();
    // this pattern will look for where reply messages start
    Pattern ReplyPattern = Pattern.compile('(?mis)^(.*?)(-+\\s*(This is a copy of the )?original (message|request)|(from|wr(ote|ites)):).*'); 
    
    for (EmailMessage Msg : Trigger.new) {
    	// create a new CaseComment object
        CaseComment myComment = new CaseComment();
        
        // copy the relevent data from the email into the case comment
        myComment.Commentbody = 'To: '+ Msg.ToAddress +
            '\nFrom: ' + Msg.FromName + ' ' + Msg.FromAddress ;
        if(Msg.CcAddress != null ) {
            myComment.Commentbody += '\nCc: ' + Msg.CcAddress ;
        }
        myComment.Commentbody += '\nSubject: ' + Msg.Subject ;
        
        // pick the usable message body
        String TheBody = (Msg.TextBody != null) ?  Msg.TextBody : Msg.HtmlBody;
        
        if(TheBody == null || TheBody.length() <= 1) TheBody = 'Empty Email';

        // look for the reply pattern
        Matcher ReplyMatcher = ReplyPattern.matcher(TheBody);
        
        // If the reply pattern is found, pull off the message bfore it and use that
        if ( ReplyMatcher.matches()) {
        	myComment.Commentbody += '\n\n' + ReplyMatcher.group(1);
        	system.debug('\n #### the previous replies have been removed');
        } else {
            system.debug('\n #### no previous replies were found');
            myComment.Commentbody += '\n\n' + TheBody;
        }
        
        myComment.ParentId = Msg.ParentId;

        // truncate the message if it is too long        
        if(myComment.Commentbody.length() > 3965) {
            myComment.Commentbody = myComment.Commentbody.substring(0,3965) + '\n### comment was truncated!' ; // truncate the body
            system.debug('#### comment was truncated\n');
        }
        
        system.debug('#### Comment = '+myComment);
        // save the case comment
        NewComments.add(myComment);
    }
    
    if (NewComments.size() > 0) {
    	Database.SaveResult[] SR = Database.insert(NewComments,false);
        // check for errors on any of the records
        for (Database.SaveResult result :SR) {
            if(!result.isSuccess()) {
                Database.Error err = result.getErrors()[0];
                system.debug('\n### ERROR - AddEmailToCaseNotes - unable to save CaseComments record - '+ result.getErrors() );
            }
        }
    }
    
}