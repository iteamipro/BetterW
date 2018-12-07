#import "headers/WAMessage.h"
#import "headers/WAChatCellData.h"
#import "headers/WAMessageAudioSliceView.h"

#import "_Pr0_Utils.h"
#import "_opus_conversor.h"

#import <Speech/Speech.h>


NSString* GLOBAL_LOCALE = @"en_US";

bool GLOBAL_IS_PROCESSING = false;


void audioAsText(const NSString* fileIn) {

	const char* inFilePath = [fileIn UTF8String];

	NSString* outFile = [fileIn stringByAppendingString:@".wav"];
	const char* outFilePath = [outFile UTF8String];

	UIActivityIndicatorView* activityIndicator = [[UIActivityIndicatorView alloc]initWithFrame:CGRectMake(0, 0, 50, 50)];
	[activityIndicator setActivityIndicatorViewStyle:UIActivityIndicatorViewStyleWhiteLarge];
	[activityIndicator setColor:[UIColor redColor]];

	UIView * topView = FUNCTION_getTopView();

	activityIndicator.center = topView.center;
	[topView addSubview:activityIndicator];

	[activityIndicator startAnimating];

	int result = pr0crustes_convertOpusFile(inFilePath, outFilePath);

	if (result == 0) {
		NSURL *url = [[NSURL alloc] initFileURLWithPath:outFile];

		NSLocale* local = [[NSLocale alloc] initWithLocaleIdentifier:GLOBAL_LOCALE];
		SFSpeechRecognizer* speechRecognizer = [[SFSpeechRecognizer alloc] initWithLocale:local];

		SFSpeechURLRecognitionRequest *urlRequest = [[SFSpeechURLRecognitionRequest alloc] initWithURL:url];
		urlRequest.shouldReportPartialResults = false;  // Report only when done.
		
		[speechRecognizer recognitionTaskWithRequest:urlRequest resultHandler:
			^(SFSpeechRecognitionResult* result, NSError* error) {
				
				[activityIndicator stopAnimating];
				[activityIndicator release];

				NSString *message = error ? [NSString stringWithFormat:@"Error processing text -> \n%@\nMay be your connection.", error] : result.bestTranscription.formattedString;
				
				UIAlertController* alert = [UIAlertController alertControllerWithTitle:@"AudioToText Result:\n" message:message preferredStyle:UIAlertControllerStyleAlert];

				UIAlertAction* closeAction = [UIAlertAction actionWithTitle:@"Close" style:UIAlertActionStyleDefault handler:nil];
				[alert addAction:closeAction];
				
				[[NSFileManager defaultManager] removeItemAtPath:outFile error:nil];  // delete temp .wav file
				FUNCTION_presentAlert(alert, true);

				GLOBAL_IS_PROCESSING = false;
			}
		];
	}
}


%group GROUP_AUDIO_TO_TEXT

	%hook WAMessageAudioSliceView

	    %property (nonatomic, assign) BOOL pr0crustes_didConnectButton; // Make sure the button is only connected once.

		%new
		-(void)pr0crustes_onButtonHold:(UILongPressGestureRecognizer *)recognizer {

			if (recognizer.state == UIGestureRecognizerStateBegan && !GLOBAL_IS_PROCESSING) {
				GLOBAL_IS_PROCESSING = true;
				
				WAChatCellData* data = MSHookIvar<WAChatCellData *>(self, "_lastCellData");
				NSString* mediaPath = [[data message] mediaPath];

				audioAsText(mediaPath);
			}
			
		}

		-(void)layoutSubviews {
			%orig;

			if (!self.pr0crustes_didConnectButton) {

				UIButton* button = MSHookIvar<UIButton *>(self, "_playPauseButton");
				UILongPressGestureRecognizer* buttonHold = [[UILongPressGestureRecognizer alloc] initWithTarget:self action:@selector(pr0crustes_onButtonHold:)];
				[button addGestureRecognizer:buttonHold];

				self.pr0crustes_didConnectButton = true;
			}
		}

	%end

%end



%ctor {

	if (FUNCTION_prefGetBool(@"pref_audio_to_text")) {
		FUNCTION_logEnabling(@"Audio To Text");
		GLOBAL_LOCALE = FUNCTION_prefGet(@"pref_audio_to_text_locale");
		%init(GROUP_AUDIO_TO_TEXT);
	}

}