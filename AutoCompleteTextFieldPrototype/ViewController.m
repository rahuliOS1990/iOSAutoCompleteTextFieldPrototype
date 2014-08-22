//
//  ViewController.m
//  AutoCompleteTextFieldPrototype
//
//  Created by R. Sharma on 8/20/14.
//  Copyright (c) 2014 AgileMobileDev. All rights reserved.
//

#import "ViewController.h"

@interface ViewController ()

@end

@implementation ViewController

- (void)viewDidLoad
{
    [super viewDidLoad];
    
    

    
    
   [txtField setPlaceholder:@"Add a Focus"];
    [txtField setValue:[UIFont fontWithName:@"AvenirNext-MediumItalic" size:16] forKeyPath:@"_placeholderLabel.font"];
    [txtField setValue:[UIColor colorWithWhite:0.600 alpha:1.000] forKeyPath:@"_placeholderLabel.textColor"];
    
    [txtField setFont:[UIFont fontWithName:@"AvenirNext-Bold" size:16.0f]];
    [txtField setTextColor:[UIColor colorWithRed:51/255.0f green:51/255.0f blue:51/255.0f alpha:1.0f]];
    
    [txtField setFontForAutoCompleteTextInsideTextField:[UIFont fontWithName:@"AvenirNext-Bold" size:16.0f]];
    
   
    
    [txtField setColorForAutoCompleteTextInsideTextField:[UIColor colorWithRed:153/255.0f green:153/255.0f blue:153/255.0f alpha:1.0f]];
    
    [txtField setAutoCompleteTableCellTextColor:[UIColor colorWithRed:153/255.0f green:153/255.0f blue:153/255.0f alpha:1.0f]];

    [txtField setAutoCompleteRegularFontName:@"AvenirNext-Bold"];
    [txtField setAutoCompleteFontSize:16.0f];
    [txtField setAutoCompleteRowHeight:22.0f];
    [txtField setMaximumNumberOfAutoCompleteRows:10];
    [txtField setAutoCompleteTableViewFooterHeight:5.0f];
        [txtField setAutoCompleteTableViewHeaderHeight:5.0f];
   
    [txtField setApplyBoldEffectToAutoCompleteSuggestions:NO];
    txtField.tintColor = [UIColor greenColor];
    
     
    [txtField setAutoCompletePlaceholderTextColor:[UIColor colorWithRed:153/255.0f green:153/255.0f blue:153/255.0f alpha:1.0f]];
    [txtField setFontForAutoCompletePlaceholder:[UIFont fontWithName:@"AvenirNext-MediumItalic" size:16.0f]];
    
    txtField.autoCompleteDataSource=self;
    txtField.autoCompleteDelegate=self;
    
    
    


	// Do any additional setup after loading the view, typically from a nib.
}

-(void)viewDidAppear:(BOOL)animated
{
    [super viewDidAppear:animated];

    
}
#pragma mark- TextField Delegate

- (BOOL)textFieldShouldReturn:(UITextField *)textField
{
    [textField resignFirstResponder];
    return YES;
}

#pragma mark- AutoComplete Datasources

- (void)autoCompleteTextField:(LSAutoCompleteTextField *)textField
 possibleCompletionsForString:(NSString *)string
            completionHandler:(void (^)(NSArray *))handler
{
    dispatch_queue_t queue = dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_HIGH, 0);
    dispatch_async(queue, ^{
        
        NSArray *completions=[NSArray arrayWithObjects:@"Amity",@"Bat",@"Cat",@"Batsman",@"Uganda",@"Cricket",@"Alexander", nil];
        handler(completions);
    });
}
- (void)didReceiveMemoryWarning
{
    [super didReceiveMemoryWarning];
    // Dispose of any resources that can be recreated.
}

@end
