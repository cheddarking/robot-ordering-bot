*** Settings ***
Documentation   Orders robots from RobotSpareBin Industries Inc.'s website.
...             Saves the order HTML receipt as a PDF file in the output folder.
...             Saves the screenshot of the ordered robot.
...             Embeds the screenshot of the robot to the PDF receipt.
...             Creates a ZIP archive of the PDFs containg the receipt and the screenshot image for each order.
Library           RPA.Browser.Selenium
Library           RPA.Tables
Library           RPA.FileSystem
Library           RPA.HTTP
Library           RPA.PDF
Library           RPA.Archive
Library           RPA.Dialogs
Library           RPA.Robocloud.Secrets



# +
*** Variables ***

${GLOBAL_RETRY_AMOUNT}    3x
${GLOBAL_RETRY_INTERVAL}    0.5s
${OUTPUT_DIRECTORY}=    ${CURDIR}${/}output
${CSV_URL}
${ORDERING_URL}
# -

*** Keywords ***
Collect Link to Orders File From User
    Add heading     Provide The Link To The Orders File
    Add text input
    ...    name=url_link
    ...    label=Enter the link to the CSV file with order data
    ...    placeholder=Enter the URL here...
    ${response}=    Run dialog
    [Return]    ${response.url_link}

*** Keywords ***
Get Link from User and Download The Orders CSV file
    ${CSV_URL}=    Collect Link to Orders File From User
    Download    ${CSV_URL}    overwrite=True

*** Tasks ***
Test Download
    #Collect Link to Orders File From User
    Get Link from User and Download The Orders CSV file

*** Keywords ***
Get the ordering website link from the vault
    ${secret}=    Get Secret    order-website
    # Note: in real robots, you should not print secrets to the log. this is just for demonstration purposes :)
    [Return]    ${secret}[url]
   

*** Keywords ***
Open The Ordering Website
    ${ORDERING_URL}=    Get the ordering website link from the vault
    Open Available Browser    ${ORDERING_URL}

*** Keywords ***
Get rid of the pop up message
    Click Button    OK

*** Keywords ***
Fill The Order For One Item
    [Arguments]    ${order}
    Select From List By Value    id:head    ${order}[Head]
    Select Radio Button    body    ${order}[Body]    
    Input Text    xpath://*[@id="root"]/div/div[1]/div/div[1]/form/div[3]/input    ${order}[Legs]
    Input Text    id:address    ${order}[Address]

*** Keywords ***
Capture a screenshot of the robot
    [Arguments]    ${order}
    #${order_number}=  ${order}[Order number]
    Click Button    id:preview
    Wait Until Element Is Visible    id:robot-preview-image    
    Screenshot    id:robot-preview-image     ${order}[Order number].png

*** Keywords ***
Submit The Order
    Click Button    id:order
    Wait Until Element Is Visible    id:receipt

*** Keywords ***
Export The Receipt As A PDF And Append the screenshot to it
    [Arguments]    ${order}
    #${order_number}=    ${order}[Order number]
    Wait Until Element Is Visible    id:receipt
    ${receipt_html}=    Get Element Attribute    id:receipt    outerHTML
    Html To Pdf    ${receipt_html}    ${CURDIR}${/}output${/}${order}[Order number].pdf
    ${files}=    Create List
    ...    ${CURDIR}${/}${order}[Order number].png:align=center
    Add Files To Pdf    ${files}   target_document=${CURDIR}${/}output${/}${order}[Order number].pdf    append=True    


*** Keywords ***
Order Next Robot
    Click Button    id:order-another

*** Keywords ***
Place The Orders Using The Data From The Orders File
    ${orders}=    Read table from CSV    orders.csv    header=True
    FOR    ${order}    IN    @{orders}
        Get rid of the pop up message
        Fill The Order For One Item     ${order}
        Capture a screenshot of the robot    ${order}
        #Submit The Order
        Wait Until Keyword Succeeds   ${GLOBAL_RETRY_AMOUNT}    ${GLOBAL_RETRY_INTERVAL}    Submit The Order
        Export The Receipt As A PDF And Append the screenshot to it    ${order}
        Order Next Robot
        #Wait Until Keyword Succeeds   ${GLOBAL_RETRY_AMOUNT}    ${GLOBAL_RETRY_INTERVAL}    Order Next Robot
    END

*** Keywords ***
Zip the Order PDFs
    ${zip_file_name}=    Set Variable    ${OUTPUT_DIRECTORY}/orders.zip
    Archive Folder With Zip  ${CURDIR}${/}output  ${zip_file_name}  include=*.pdf

*** Keywords ***
Close The Browser
    Close Browser

*** Tasks ***
Place the orders on the ordering website
    Get Link from User and Download The Orders CSV file
    Open The Ordering Website
    Place The Orders Using The Data From The Orders File
    Zip the Order PDFs
    [Teardown]    Close The Browser
