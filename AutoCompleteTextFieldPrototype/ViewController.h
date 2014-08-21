//
//  ViewController.h
//  AutoCompleteTextFieldPrototype
//
//  Created by R. Sharma on 8/20/14.
//  Copyright (c) 2014 AgileMobileDev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "LSAutoCompleteTextField.h"

@interface ViewController : UIViewController<LSAutoCompleteTextFieldDataSource,LSAutoCompleteTextFieldDelegate,UITextFieldDelegate>

{
    IBOutlet LSAutoCompleteTextField *txtField;
    IBOutlet UITextField *txt1;
}
@end
