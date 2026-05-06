# job_platform_frontend

A new Flutter project.

## Getting Started

This project is a starting point for a Flutter application.

A few resources to get you started if this is your first Flutter project:

- [Learn Flutter](https://docs.flutter.dev/get-started/learn-flutter)
- [Write your first Flutter app](https://docs.flutter.dev/get-started/codelab)
- [Flutter learning resources](https://docs.flutter.dev/reference/learning-resources)

For help getting started with Flutter development, view the
[online documentation](https://docs.flutter.dev/), which offers tutorials,
samples, guidance on mobile development, and a full API reference.

## TODO
Job listings location filtering keyboard hides text box

Adding a call message in chat preview displays the raw json

For use case "Διαχείριση αιτήσεων υποψήφιων εργαζομένων"

Job applications filtering doesnt appear on UI

Job applications searching isnt implemented

Profile sheet (tapping profile image) -> View candidate profile doesnt show skills, education, work experience. Also skill?


For use case "Use case «Συστήμα Μηνυμάτων»"
Tapping + doesnt show a list of all platform users: Only searching is existent Maybe a feature?
Tapping and holding a message insta deletes it (there should be a manu based on use cases and common sense)


For use case "Use case «Συνεντεύξεις μέσα από την πλατφόρμα»"
Error messages in UI are not clear: Meeting date is in the future, date pick is in the past in picker
No error message like alt flow 4 appears when missing permissions


For use case "10. Use case «Σύστημα αξιολογήσεων εταιριών»"
Missing alternative flow 2 (probably drop)
Missing alternative flow 3 (we can add it)
Message "Η κριτική σας υποβλήθηκε επιτυχώς" doesnt exist

For use case "11. Use case «Social networking»"
"Η δημοσίευσή σας ανέβηκε" message doesnt exist
Εναλλακτική ροή 2 (Υπέρβαση ορίου χαρακτήρων ή μεγέθους αρχείου) there is no text limit and file limit is 20MB iirc (verify this but i think it's only for public nginx server)

For use case "3. Use case «Home menu υποψηφίου: Προβολή αγγελιών εργασίας »"
Nothing, just hook up cv builder maybe in the report when we write it

For use case "4. Use case «Home menu εργοδότη: Διαχείριση αγγελιών εργασίας»"
Error messages show below the screen "Create job posting"
Success message doesnt exist

someone with no experience can leave a review

skills and experiences are just text 

imp:remove ai session completely from our app and instead integrate it with calendar

cvs letter arent visible 

cv builder should get data from profile and you should be able to create a cv when in edit mode in profile for better integration

bug:mock ai interview doesnt have starting prompt and instead has a hello

bug:redirect from mock ai interviews sometimes doesnt work

bug:you wait 30 seconds to logout and for the app to start when the server is down or unresponsive

suggestion:maybe fix live searching in searching for user to message screen

bug:scroll to bottom when leaving a comment on post on socials

rework:like system in socials is too complicated when it doesnt need to.on post just togle a boolean in the server and frontend

rename:ShowcreateSheet -> displayCreatePostSheet

bug:sometime when llm takes too long to respond we timeout and throw an error message when we shoulnt and then the llm responds anyway

rename:SearchControler to searchBar

diag:rename reviewScreen to something better
