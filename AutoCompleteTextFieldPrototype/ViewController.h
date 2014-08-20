//
//  ViewController.h
//  AutoCompleteTextFieldPrototype
//
//  Created by R. Sharma on 8/20/14.
//  Copyright (c) 2014 AgileMobileDev. All rights reserved.
//

#import <UIKit/UIKit.h>
#import "MLPAutoCompleteTextField.h"

@interface ViewController : UIViewController<MLPAutoCompleteTextFieldDataSource,MLPAutoCompleteTextFieldDelegate,UITextFieldDelegate>

{
    IBOutlet MLPAutoCompleteTextField *txtField;
}
@end
