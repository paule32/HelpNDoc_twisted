// -----------------------------------------------------------------------
// File:   MergeTopicsWithTemplate.hnd.pas
//
// Author: Jens Kallup - paule32 <paule32.jk@gmail.com>
// Rights: (c) 2023 kallup non-profit.
//
// Desc: Make Help Project Topics ready with finally merge them, after
//       a Template Topic is proceed. Each Topic within the Project will
//       be convert, except the Template Topic itself.
//       The Template Topic can included Snippets, which has HTML stuff,
//       too. The reminder mark [::BODY::] is used, to merge the content
//       between Template and normal Topic.
//       After each Topic is converted, the reminder mark "sBlockREM" is
//       append to the Html Topic content, to check, if the Topic is
//       already converted.
//       The result of all this working tasks is a new HelpNDoc Project
//       file.
// -----------------------------------------------------------------------
// User Actions required (if they don't exists as Variable):
// 1. create Topic, named with "Vorlage",
// 2. change the constant "sTemplate" with the name, that you give under
//    point 1.
// 3. in the created Topic, add "sBodyMark" -> this mark will be used, to
//    sign, where the content of the normal Topic should be appear.
// 4. set sOutFiles directory for content output location
// -----------------------------------------------------------------------
const sLibFiles = 'E:\Projekte\Temp\'; // default output directory
const sTemplate = 'Vorlage';           // the Template topic name
const sBuildTyp = 'chm';               // the build type

const sBodyMark   = '[::BODY::]';      // a bookmark in Template for adding text
const sReminder   = '<!-- Topic converted -->';  // convert reminder
const sDeleteTemp = 'yes';             // delete output folder ?

// -----------------------------------------------------------------------
// EUA - End of User Actions.
// -----------------------------------------------------------------------
var userLib_BuildType: String;
var userLib_Files    : String;
var userLib_Template : String;
var userLib_BodyMark : String;
var userLib_Reminder : String;
var userLib_DeleteOld: String;

var oEditor, oEditorTemp : TObject;
var oSnippet             : TObject;

var oTempMem      : TMemoryStream;
var oFileNameList : TStringList;

var sTopicID, sRootTopicID: String;

var sCaptStr, sTempStr, sTmpStr   : String;
var sHtmlStr      : String;
var sFileContent  : String;

var sProjectName  : String;
var sProjectFolder: String;

var sKeywordID : String;
var iKeywordLevel : Integer;

var sDefaultTopicID : String;
var sDefaultBuildID : String;

var sDefaultLogFile : String = 'project.log';
var sDefaultIdxFile : String = 'index.hhk';
var sDefaultTocFile : String = 'toc.hhc';
var sDefaultTocFont : String = 'Arial,10,0';

var cssOutput: String;

var aTopicList   : THndTopicsInfoArray;
var aLibItems    : THndLibraryItemsInfoArray;
var aKeywordList : THndKeywordsInfoArray;
var aBuildList   : THndBuildInfoArray;

var aAssociatedTopics: array of string;

var iCounter, opt: Integer;

var nBlocLevel: integer = 0;
var nCurKeyword, nCurKeywordLevel, nDif, nClose, nAssociatedTopic: integer;
var sCurrentKeyword, sRelativeTopic: string;
var aBreadCrumb: array of String;

var nCurParent, nTopicKind, nHeaderKind, nFooterKind: integer;
var nIconIndex: integer;

var sTopicUrl: string;
var sTopicHeader: String;
var sTopicFooter: String;

var sHtmlTemplateStr: String;

var nCurTopic, nCurTopicLevel: integer;

// -----------------------------------------------------------------------
// this function check, if the user variables exists, else they will not
// be overwrite - because they are already defined on Top of this Code
// (at the User-Actions List) ...
// -----------------------------------------------------------------------
function CheckUserVariables(aTopicID: String): Boolean;
const userLib_PropFiles     = 'userLib_Files'    ;
const userLib_PropBuildType = 'userLib_BuildType';
const userLib_PropDeleteOld = 'userLib_DeleteOld';
const userLib_PropTemplate  = 'userLib_Template' ;
const userLib_PropReminder  = 'userLib_Reminder' ;
const userLib_PropBodyMark  = 'userLib_Bodymark' ;
begin
  result := true;

  if not HndTopicsProperties.GetTopicCustomPropertyExists(
  aTopicID,userLib_PropFiles) then
  begin
    HndTopicsProperties.SetTopicCustomPropertyValue(
    aTopicID,userLib_PropFiles,sLibFiles);
  end;

  userLib_Files := HndTopicsProperties.GetTopicCustomPropertyValue(
  aTopicID,userLib_PropFiles);

  //
  if not HndTopicsProperties.GetTopicCustomPropertyExists(
  aTopicID,userLib_PropBuildType) then
  begin
    HndTopicsProperties.SetTopicCustomPropertyValue(
    aTopicID,userLib_PropBuildType,sBuildTyp);
  end;

  userLib_BuildType := HndTopicsProperties.GetTopicCustomPropertyValue(
  aTopicID,userLib_PropBuildType);

  //
  if not HndTopicsProperties.GetTopicCustomPropertyExists(
  aTopicID,userLib_PropDeleteOld) then
  begin
    HndTopicsProperties.SetTopicCustomPropertyValue(
    aTopicID,userLib_PropDeleteOld,sDeleteTemp);
  end;

  userLib_DeleteOld := HndTopicsProperties.GetTopicCustomPropertyValue(
  aTopicID,userLib_PropDeleteOld);

  //
  if not HndTopicsProperties.GetTopicCustomPropertyExists(
  aTopicID,userLib_PropTemplate) then
  begin
    HndTopicsProperties.SetTopicCustomPropertyValue(
    aTopicID,userLib_PropTemplate,sTemplate);
  end;

  userLib_Template := HndTopicsProperties.GetTopicCustomPropertyValue(
  aTopicID,userLib_PropTemplate);

  //
  if not HndTopicsProperties.GetTopicCustomPropertyExists(
  aTopicID,userLib_PropReminder) then
  begin
    HndTopicsProperties.SetTopicCustomPropertyValue(
    aTopicID,userLib_PropReminder,sReminder);
  end;

  userLib_Reminder := HndTopicsProperties.GetTopicCustomPropertyValue(
  aTopicID,userLib_PropReminder);

  //
  if not HndTopicsProperties.GetTopicCustomPropertyExists(
  aTopicID,userLib_PropBodymark) then
  begin
    HndTopicsProperties.SetTopicCustomPropertyValue(
    aTopicID,userLib_PropBodymark,sBodyMark);
  end;

  userLib_Bodymark := HndTopicsProperties.GetTopicCustomPropertyValue(
  aTopicID,userLib_PropBodymark);
end;

function GetCompatibilityModeMeta(): string;
var sVersion: string;
begin
  Result := '';
  sVersion := HndGeneratorInfo.GetCustomSettingValue('IECompatibilityMode');
  if Copy(sVersion, 1, 3) = 'IE=' then
  result := Format('<meta http-equiv="X-UA-Compatible" content="%s">', [sVersion]);
end;

function GetCustomCss: string;
begin
  result := HndGeneratorInfo.GetCustomSettingValue('CustomCss');
  if (result <> '') then
  result := '<style type="text/css">' + Result + '</style>';
end;

function GetCustomJs: string;
begin
  result := HndGeneratorInfo.GetCustomSettingValue('CustomJs');
  if (result <> '') then
  result := '<script type="text/javascript">try{' + #13#10 + Result + #13#10 + '}catch(e){alert("Exception in custom JavaScript Code: " + e);}</script>';
end;

// Returns the footer
function GetTemplateHtmlFooter: string;
begin
  result := HndGeneratorInfo.GetCustomSettingValue('Footer');
end;

// Returns the description of the topic
function GetTopicDescription: string;
begin
  // Get value
  result := HndTopics.GetTopicDescription(HndGeneratorInfo.CurrentTopic);
  // Empty ? Use project's description instead
  if (result = '') then result := HndProjects.GetProjectSummary;
end;

// -----------------------------------------------------------------------
// Entry point of this Pascal-Script ...
// -----------------------------------------------------------------------
begin
  // Special encoding needs to be done for CHM documentation
  HndGeneratorInfo.ForceOutputEncoding := True;

  // finally try
  try
    // exception try
    try
      // ---------------------------------------------------------------
      // first, we look how many Topic exists. If the Template Topic
      // is in the Project, then we read the contents of this Template,
      // and insert it to each Topic, we can found ...
      // ---------------------------------------------------------------
      aTopicList := HndTopics.GetTopicList(false);
      for iCounter := 0 to Length(aTopicList) - 1 do
      begin
        if aTopicList[iCounter].Caption = sTemplate then
        begin
          sTopicID := aTopicList[iCounter].ID;
          CheckUserVariables(sTopicID);
          break;
        end;
      end;

      // ---------------------------------
      // sanity check, if Topic found ...
      // ---------------------------------
      if Length(Trim(sTopicID)) < 1 then
      begin
        ShowMessage('Error:' + #13#10    +
        'Template Topic: '   + sTemplate + '.' + #13#10 +
        'does not exists, aborted.');
        exit;
      end;

      oEditor     := HndEditor.CreateTemporaryEditor;
      oEditorTemp := HndEditor.CreateTemporaryEditor;
      oTempMem    := TMemoryStream.Create;

      // -----------------------------------------------------
      // now, we replace the (Snippet-Content) named "Text"
      // with the given Library Item content ...
      // -----------------------------------------------------
      aLibItems := HndLibraryItems.GetItemList([7]);
      if aLibItems.Count - 1 < 0 then
      begin
        ShowMessage('Warning:' + #13#10 +
        'No Library-Item for replace Text available.');
        exit;
      end;

      // ----------------------------------------------
      // here, we catch the Template Topic content ...
      // ----------------------------------------------
      oTempMem.Clear;
      oTempMem := HndTopics.GetTopicContent(sTopicID);

      HndEditor.Clear(oEditor);
      HndEditor.SetContent(oEditor,oTempMem);

      sHtmlStr := HndEditor.GetContentAsHtml(oEditor,cssOutput);

      // ---------------------------------------------------------
      // before we do something, we check, if the normal Topic
      // is already merged with Template Topic content ...
      // ---------------------------------------------------------
      if Pos(userLib_Reminder,sHtmlStr) > 0 then
      begin
        ShowMessage('Warning:' + #13#10 +
        'Topic is already merged with Template Topic content.');
        exit;
      end;

      // ---------------------------------------------------------
      // for each Snippet, we merge the normal Topic content with
      // the content of the Template Topic ...
      // ---------------------------------------------------------
      for iCounter := 0 to aLibItems.Count - 1 do
      begin
        sTopicID := aLibItems[iCounter].ID;
        sTempStr := aLibItems[iCounter].Caption;

        if Pos(sTempStr,sHtmlStr) > 0 then
        begin
          oTempMem.Clear;
          oTempMem := HndLibraryItems.GetItemContent(sTopicID);

          HndEditor.Clear(oEditorTemp);
          HndEditor.SetContent(oEditorTemp,oTempMem);

          sTempStr := HndEditor.GetContentAsHtml(oEditorTemp,cssOutput);

          sHtmlStr := StringReplace(
          sHtmlStr,aLibItems[iCounter].Caption,
          sTempStr,[rfReplaceAll]);
        end;
      end;

      // -------------------------------------------------------------
      // now, we have add the Snippet's - we replace the normal Topic
      // content with "sHtmlStr" -> [::BODY::] ...
      // -------------------------------------------------------------
      sHtmlTemplateStr := sHtmlStr;
//----
      sProjectFolder := userLib_Files + ChangeFileExt(
      ExtractFileName(HndProjects.GetProjectName),'') + '_html\';

      // ---------------------------------------------------
      // depend on DeleteDir, we delete the output folder
      // before we write the new topic files ...
      // ---------------------------------------------------
      if DirectoryExists(sProjectFolder) then
      begin
        if CompareStr(LowerCase(userLib_DeleteOld),'yes') = 0 then opt := 1 else
        if CompareStr(LowerCase(userLib_DeleteOld),'no' ) = 0 then opt := 0 else
        raise Exception.Create('boolean String: yes/no expected');

        if opt = 1 then RemoveDir(sProjectFolder);
      end;

      // ---------------------------------------------------
      // then, we create fresh, empty folder ...
      // ---------------------------------------------------
      if not DirectoryExists(sProjectFolder) then
      if not CreateDir(sProjectFolder) then
      begin
        raise Exception.Create(
        'Project Directory could not be created: ' + #13#10 +
        sProjectFolder);
      end;

      // ----------------------------
      // write project file ...
      // ----------------------------
      sDefaultTopicID := HndProjects.GetProjectDefaultTopic();
      sDefaultTopicID := HndTopics  .GetTopicHelpId(sDefaultTopicId);

      // --------------------------------------------
      // check, if build already present, if so then
      // delete this build ...
      // --------------------------------------------
      aBuildList := HndBuilds.GetBuildList;

      for iCounter := 0 to Length(aBuildList) - 1 do
      begin
        if CompareStr(aBuildList[iCounter].Name,userLib_BuildType + '_Build') <> 0 then
        begin
          HndBuilds.DeleteBuild(aBuildList[iCounter].ID);
          break;
        end;
      end;

      sDefaultBuildID := HndBuilds.CreateBuild;

      HndBuilds.SetBuildKind   (sDefaultBuildID,userLib_BuildType);
      HndBuilds.SetBuildName   (sDefaultBuildID,userLib_BuildType + '_Build');

      if (CompareStr(LowerCase (userLib_BuildType),'chm' ) = 0) then
      HndBuilds.SetBuildOutput (sDefaultBuildID,userLib_Files + 'index.chm') else

      if (CompareStr(LowerCase (userLib_BuildType),'htm' ) = 0)
      or (CompareStr(LowerCase (userLib_BuildType),'html') = 0) then
      HndBuilds.SetBuildOutput (sDefaultBuildID,userLib_Files);

      HndBuilds.MoveBuildFirst (sDefaultBuildID);
      HndBuilds.SetBuildEnabled(sDefaultBuildID,true);

      sDefaultBuildID := HndBuilds.GetBuildOutput(sDefaultBuildID);

      sDefaultLogFile := sProjectFolder + sDefaultLogFile;
      sDefaultTocFile := sProjectFolder + sDefaultTocFile;
      sDefaultIdxFile := sProjectFolder + sDefaultIdxFile;

      sFileContent :=
      '[OPTIONS]'                              + #13#10 +
      'Compatibility=1.1 or later'             + #13#10 +
      'Display compile progress=Yes'           + #13#10 +
      'Full-text search=Yes'                   + #13#10 +
      'Default Font='   + Format('%s',     [sDefaultTocFont]) + #13#10 +
      'Error log file=' + Format('%s',     [sDefaultLogFile]) + #13#10 +
      'Contents file='  + Format('%s',     [sDefaultTocFile]) + #13#10 +
      'Index file='     + Format('%s',     [sDefaultIdxFile]) + #13#10 +
      'Compiled file='  + Format('%s',     [sDefaultBuildID]) + #13#10 +
      'Default topic='  + Format('%s.html',[sDefaultTopicID]) + #13#10 +
      'Language='       + Format('0x%.4x', [HndProjects.GetProjectLanguage()]) + #13#10 +
      'Title='          + Format('%s',     [HndProjects.GetProjectTitle   ()]) + #13#10 +
      ''                                                                       + #13#10 +
      '[WINDOWS]'                                                              + #13#10 +
      Format('Main="%s","%s","%s","%s","%s","%s","%s","%s","%s",%s,%d,%s' +
      ',[%d,%d,%d,%d],0xB0000,,,%d,0,0,0', [
      HndProjects.GetProjectTitle,
      sDefaultTocFile,
      sDefaultIdxFile,
      sDefaultTopicID + '.html',
      HndBuildsMeta.GetItemMetaStringValue(HndGeneratorInfo.CurrentBuildId, 'WinHomeUrl', sDefaultTopicID + '.html'),
      HndBuildsMeta.GetItemMetaStringValue(HndGeneratorInfo.CurrentBuildId, 'WinJump1Url', ''),
      HndBuildsMeta.GetItemMetaStringValue(HndGeneratorInfo.CurrentBuildId, 'WinJump1Caption', ''),
      HndBuildsMeta.GetItemMetaStringValue(HndGeneratorInfo.CurrentBuildId, 'WinJump2Url', ''),
      HndBuildsMeta.GetItemMetaStringValue(HndGeneratorInfo.CurrentBuildId, 'WinJump2Caption', ''),
      HndBuildsMetaEx.GetChmNavigationPaneStyleHex(HndGeneratorInfo.CurrentBuildId),
      HndBuildsMeta.GetItemMetaIntValue(HndGeneratorInfo.CurrentBuildId, 'WinTabNavWidth', 200),
      HndBuildsMetaEx.GetChmButtonVisibilityHex(HndGeneratorInfo.CurrentBuildId),
      HndBuildsMeta.GetItemMetaIntValue(HndGeneratorInfo.CurrentBuildId, 'WinPosLeft', -1),
      HndBuildsMeta.GetItemMetaIntValue(HndGeneratorInfo.CurrentBuildId, 'WinPosTop', -1),
      HndBuildsMeta.GetItemMetaIntValue(HndGeneratorInfo.CurrentBuildId, 'WinPosRight', -1),
      HndBuildsMeta.GetItemMetaIntValue(HndGeneratorInfo.CurrentBuildId, 'WinPosBottom', -1),
      Integer(not HndBuildsMeta.GetItemMetaBoolValue(HndGeneratorInfo.CurrentBuildId, 'WinTabNavVisible', True))
      ]) + #13#10#13#10;

      sFileContent := sFileContent +
      '[FILES]'  + #13#10 ;

      // Topics
      for iCounter := 0 to Length(aTopicList) - 1 do
      begin
        // 1 => Empty topic
        if aTopicList[iCounter].Kind <> 1 then
        begin
          // userLib_Template ?
          if CompareStr(aTopicList[iCounter].HelpId,userLib_Template) = 0 then
          continue;
          sFileContent := sFileContent +
          Format('%s.html', [LowerCase(aTopicList[iCounter].HelpId)]) + #13#10;
        end;
      end;

      oFileNameList := TStringList.Create;
      oFileNameList.WriteBOM := false;
      oFileNameList.Add(sFileContent);
      oFileNameList.SaveToFile(sProjectFolder + 'HelpTest.hhp');
      oFileNameList.Clear;
      oFileNameList.Free;

      // --------------------------------
      // write a index/keyword file ...
      // --------------------------------
      sFileContent :=
      '<HTML>'                                         + #13#10 +
      '<HEAD><meta name="GENERATOR" '                  + #13#10 +
      ' content="kallup non-profit HelpNDoc Tools">'   + #13#10 +
      '</HEAD><BODY>'                                  + #13#10 +
      '<UL>'                                           + #13#10 ;

      aKeywordList := HndKeywords.GetKeywordList(false);
      for nCurKeyword := 0 to length(aKeywordList) - 1 do
      begin
        sCurrentKeyword := aKeywordList[nCurKeyword].id;
        nCurKeywordLevel := HndKeywords.GetKeywordLevel(sCurrentKeyword);

        // Associated topics
        aAssociatedTopics := HndTopicsKeywordsEx.
        GetGeneratedTopicsAssociatedWithKeyword(sCurrentKeyword);

        // Close the previous keywords
        if ((nCurKeyword > 0) and (nCurKeywordLevel < HndKeywords.
        GetKeywordLevel(aKeywordList[nCurKeyword-1].id))) then
        begin
          nDif := HndKeywords.GetKeywordLevel(
          aKeywordList[nCurKeyword-1].id)-nCurKeywordLevel;
          iKeywordLevel;
          for nClose := 0 to nDif - 1 do
          begin
            sFileContent := sFileContent + '</ul></li>' + #13#10;
            nBlocLevel := nBlocLevel - 1;
          end;
        end;

        sFileContent := sFileContent +
        '<li>' + #13#10#9 +
        '<object type="text/sitemap">' + #13#10#9#9 +
        '<param name="Name" value="' +
        Format('%s', [
        HndUtils.HTMLEncode(
        HndKeywords.GetKeywordCaption(sCurrentKeyword))]) + '">' + #13#10;

        if (Length(aAssociatedTopics) > 0) then
        begin
          for nAssociatedTopic := 0 to Length(aAssociatedTopics) - 1 do
          begin
            sFileContent := sFileContent  + #9#9 +
            '<param name="Local" value="' +
            Format('%s.html', [HndTopics.GetTopicHelpId(
            aAssociatedTopics[nAssociatedTopic])]) + '">' + #13#10;
          end;
        end else
        begin
          sFileContent := sFileContent +
          '<param name="Local" value="_empty.htm">' + #13#10;
        end;
        sFileContent := sFileContent + #9 +
        '</object>' + #13#10;

        if (HndKeywords.GetKeywordDirectChildrenCount(sCurrentKeyword) > 0) then
        begin
          sFileContent := sFileContent + #9 + '<ul>' + #13#10;
          nBlocLevel := nBlocLevel + 1;
        end else
        begin
          sFileContent := sFileContent + #9 + '</li>' + #13#10;
        end;

        // Close the last keyword
        if (HndKeywords.GetKeywordNext(sCurrentKeyword) = '') then
        begin
          while nBlocLevel > 0 do
          begin
            sFileContent := sFileContent + #9 + '</ul></li>' + #13#10;
            nBlocLevel := nBlocLevel - 1;
          end;
        end;
      end;

      sFileContent := sFileContent +
      '</UL>'                                          + #13#10 +
      '</BODY></HTML>'                                 + #13#10 ;

      oFileNameList := TStringList.Create;
      oFileNameList.WriteBOM := false;
      oFileNameList.Add(sFileContent);
      oFileNameList.SaveToFile(sProjectFolder + 'index.hhk');
      oFileNameList.Clear;
      oFileNameList.Free;

      // --------------------------------
      // write Table of Contents file ...
      // --------------------------------
      sFileContent :=
      '<HTML>'                                         + #13#10 +
      '<HEAD><meta name="GENERATOR" '                  + #13#10 +
      ' content="kallup non-profit HelpNDoc Tools">'   + #13#10 +
      '</HEAD><BODY>'                                  + #13#10 +
      '<OBJECT type="text/site properties">'           + #13#10 +
      '<param name="ImageType" value="Folder">'        + #13#10 +
      '</OBJECT>'                                      + #13#10 +
      '<UL>'                                           + #13#10 ;

      // List of generated topic, excluding hidden in TOC
      for nCurTopic := 0 to length(aTopicList) - 1 do
      begin
        if CompareStr(aTopicList[nCurTopic].
        Caption,userLib_Template) = 0 then
        continue;
        HndGeneratorInfo.CurrentTopic := aTopicList[nCurTopic].id;

        // Is it hidden in TOC ?
        if (aTopicList[nCurTopic].Visibility <> 0) then
        continue;

        // Topic data
        nTopicKind := aTopicList[nCurTopic].Kind;
        nCurTopicLevel := HndTopics.GetTopicLevel(HndGeneratorInfo.CurrentTopic);
        nIconIndex := HndTopics.GetTopicIconIndex(HndGeneratorInfo.CurrentTopic) + 1;

        // Topic URL
        if nTopicKind = 2 then sTopicUrl :=  HndTopics.GetTopicUrlLink(HndGeneratorInfo.CurrentTopic)
        else sTopicUrl := Format('%s.html', [HndTopics.GetTopicHelpId(HndGeneratorInfo.CurrentTopic)]);

        // Close the previous topics
        if ((nCurTopic > 0) and (nCurTopicLevel < HndTopics.GetTopicLevel(aTopicList[nCurTopic - 1].id))) then
        begin
          nDif := HndTopics.GetTopicLevel(aTopicList[nCurTopic - 1].id) - nCurTopicLevel;
          for nClose := 0 to nDif - 1 do
          begin
            sFileContent := sFileContent + '</ul></li>' + #13#10;
            nBlocLevel := nBlocLevel - 1;
          end;
        end;

        sFileContent := sFileContent +
        '<li> <object type="text/sitemap">' + #13#10 +
        '<param name="Name" value="' +
        Format('%s', [
        HTMLEncode(HndTopics.GetTopicCaption(
        HndGeneratorInfo.CurrentTopic))]) + '">' + #13#10;

        if nTopicKind <> 1 then  // Empty topic
        begin
          sFileContent := sFileContent  +
          '<param name="Local" value="' + sTopicUrl + '">' + #13#10;
        end;

        if nIconIndex > 0 then
        begin
          sFileContent := sFileContent        +
          '<param name="ImageNumber" value="' +
          Format('%d', [nIconIndex]) + '">'   + #13#10;
        end;

        sFileContent := sFileContent + '</object>' + #13#10;

        if (HndTopicsEx.GetTopicDirectChildrenCountGenerated(HndGeneratorInfo.CurrentTopic, True) > 0) then
        begin
          sFileContent := sFileContent + '<ul>' + #13#10;
          nBlocLevel := nBlocLevel + 1;
        end else
        begin
          sFileContent := sFileContent + '</li>' + #13#10;
        end;

        // Close the last topic
        if (HndTopicsEx.GetTopicNextGenerated(HndGeneratorInfo.CurrentTopic, True) = '') then
        begin
          while nBlocLevel > 0 do
          begin
            sFileContent := sFileContent + '</ul></li>' + #13#10;
            nBlocLevel := nBlocLevel - 1;
          end;
        end;
      end;

      sFileContent := sFileContent +
      '</UL>'                                          + #13#10 +
      '</BODY></HTML>'                                 + #13#10 ;

      oFileNameList := TStringList.Create;
      oFileNameList.WriteBOM := false;
      oFileNameList.Add(sFileContent);
      oFileNameList.SaveToFile(sProjectFolder + 'toc.hhc');
      oFileNameList.Clear;
      oFileNameList.Free;


    // Each individual topics generated...
    aTopicList := HndTopicsEx.GetTopicListGenerated(False, False);
    for nCurTopic := 0 to Length(aTopicList) - 1 do
    begin
      iCounter := nCurTopic;
      // Notify about the topic being generated
      HndGeneratorInfo.CurrentTopic := aTopicList[nCurTopic].id;
      if CompareStr(aTopicList[nCurTopic].Caption,userLib_Template) = 0 then
      continue;

      // Topic kind
      nTopicKind := aTopicList[nCurTopic].Kind;
      if (nTopicKind = 1) then continue;  // Empty topic: do not generate anything

      // Setup the file name
      HndGeneratorInfo.CurrentFile := HndTopics.GetTopicHelpId(HndGeneratorInfo.CurrentTopic) + '.html';

      // Topic header
      nHeaderKind := HndTopics.GetTopicHeaderKind(HndGeneratorInfo.CurrentTopic);
      sTopicHeader := HndTopics.GetTopicHeaderTextCalculated(HndGeneratorInfo.CurrentTopic);

      // Topic footer
      nFooterKind := HndTopics.GetTopicFooterKind(HndGeneratorInfo.CurrentTopic);
      sTopicFooter := HndTopics.GetTopicFooterTextCalculated(HndGeneratorInfo.CurrentTopic);

      sFileContent := '<!DOCTYPE html>' + #13#10 +
      '<html>'  + #13#10 +
      '<head>'  + #13#10 +
      '<title>' + HTMLEncode(HndTopics.GetTopicCaption(HndGeneratorInfo.CurrentTopic)) + '</title>' + #13#10 +
      '<meta http-equiv="Content-Type" content="text/html; charset="utf-8">' + #13#10 +
      GetCompatibilityModeMeta() + #13#10  +
      '<meta name="description" content="' + HTMLEncode(GetTopicDescription) + '" />' + #13#10 +
      '<meta name="generator" content="'   + HTMLEncode(HndGeneratorInfo.HelpNDocVersion) + '" />' + #13#10;

      // Redirect for URL and Files topic
      if (nTopicKind = 2) then
      begin
        sFileContent := sFileContent +
        Format('<meta http-equiv="refresh" content="0;URL=%s">', [HndTopics.GetTopicUrlLink(HndGeneratorInfo.CurrentTopic)]) + #13#10;
      end else
      begin
        sFileContent := sFileContent +
        '<link type="text/css" rel="stylesheet" media="all" href="css/reset.css" />'  + #13#10 +
        '<link type="text/css" rel="stylesheet" media="all" href="css/base.css" />'   + #13#10 +
        '<link type="text/css" rel="stylesheet" media="all" href="css/hnd.css" />'    + #13#10 +
        '<!--[if lte IE 8]>'                                                          + #13#10 +
        '<link type="text/css" rel="stylesheet" media="all" href="css/ielte8.css" />' + #13#10 +
        '<![endif]-->'                                                                + #13#10 +

        '<style type="text/css">' + #13#10 +
        '#topic_header'           + #13#10 +
        '{'                       + #13#10 +
        'background-color: #'     +
        HndUtils.TColorToHex(HndGeneratorInfo.GetCustomSettingValue('BaseColor')) + #13#10 +
        '}'                       + #13#10 +
        '</style>'                + #13#10 +
        GetCustomCss()            + #13#10 +
        '<script type="text/javascript" src="js/chmRelative.js"></script>' + #13#10;
      end;

      sFileContent := sFileContent +
      '</head>' + #13#10 +
      '<body>'  + #13#10 ;

      // Redirect for URL and Files topic
      if (nTopicKind = 2) then
      begin
        sFileContent := sFileContent +
        Format('<a href="%s">Redirecting... click here if nothing happens</a>', [HndTopics.GetTopicUrlLink(HndGeneratorInfo.CurrentTopic)]) + #13#10;
      end else
      begin
        if nHeaderKind <> 2 then
        begin
          sFileContent := sFileContent      +
          '<div id="topic_header">'         + #13#10  +
          '<div id="topic_header_content">' + #13#10  +
          '<h1>' + HTMLEncode(sTopicHeader) + '</h1>' + #13#10;

          if Length(aBreadCrumb) > 0 then
          begin
            sFileContent := sFileContent  +
            '<div id="topic_breadcrumb">' + #13#10;

            for nCurParent := Length(aBreadCrumb) - 1 downto 0 do
            begin
              // Empty topic
              if (HndTopics.GetTopicKind(aBreadCrumb[nCurParent]) = 1) then
              begin
                sFileContent := sFileContent +
                Format('%s &rsaquo;&rsaquo; ', [HTMLEncode(HndTopics.GetTopicCaption(aBreadCrumb[nCurParent]))]);
              end else
              // Normal topic
              begin
                sFileContent := sFileContent +
                Format('<a href="%s.htm">%s</a> &rsaquo;&rsaquo; ', [
                HndTopics.GetTopicHelpId(aBreadCrumb[nCurParent]),
                HTMLEncode(HndTopics.GetTopicCaption(
                aBreadCrumb[nCurParent]))]);
              end;
            end;

            sFileContent := sFileContent + '</div>' + #13#10; end;
            sFileContent := sFileContent + '</div>' + #13#10;

            if HndGeneratorInfo.GetCustomSettingValue('ShowNavigation') then
            begin
              sFileContent := sFileContent  +
              '<div id="topic_header_nav">' + #13#10;

              sRelativeTopic := HndTopics.GetTopicParent(HndGeneratorInfo.CurrentTopic);

              if (sRelativeTopic <> '') and (sRelativeTopic <> HndTopics.GetProjectTopic())
              and (HndTopics.GetTopicKind(sRelativeTopic) <> 1)  then // Skip blank topics
              begin
                sFileContent := sFileContent +
                '<a href="' + Format('%s.htm', [HndTopics.GetTopicHelpId(sRelativeTopic)]) +
                '"><img src="img/arrow_up.png" alt="Parent"/></a>';
              end;

              // Previous topic included in TOC
              sRelativeTopic := HndTopicsEx.GetTopicPreviousGenerated(HndGeneratorInfo.CurrentTopic, True);
              while (HndTopics.GetTopicKind(sRelativeTopic) = 1) do  // Skip blank topics
              sRelativeTopic := HndTopicsEx.GetTopicPreviousGenerated(sRelativeTopic, True);

              if (sRelativeTopic <> '') and (sRelativeTopic <> HndTopics.GetProjectTopic()) then
              begin
                sFileContent := sFileContent +
                '<a href="' + Format('%s.htm', [HndTopics.GetTopicHelpId(sRelativeTopic)]) + '"><img src="img/arrow_left.png" alt="Previous"/></a>'
              end;

              // Next topic included in TOC
              sRelativeTopic := HndTopicsEx.GetTopicNextGenerated(HndGeneratorInfo.CurrentTopic, True);

              while (HndTopics.GetTopicKind(sRelativeTopic) = 1) do  // Skip blank topics
              sRelativeTopic := HndTopicsEx.GetTopicNextGenerated(sRelativeTopic, True);

              if (sRelativeTopic <> '') and (sRelativeTopic <> HndTopics.GetProjectTopic()) then
              begin
                sFileContent := sFileContent +
                '<a href="' + Format('%s.htm', [HndTopics.GetTopicHelpId(sRelativeTopic)]) + '"><img src="img/arrow_right.png" alt="Next"/></a>';
              end;

              sFileContent := sFileContent + '</div>' + #13#10;
            end;

            sFileContent := sFileContent +
            '<div class="clear"></div>'  + #13#10 +
            '</div>'                     + #13#10 ;
          end;

          // -----------------------------------------
          // here, we catch the user topic content ...
          // -----------------------------------------
          oTempMem.Clear;
          oTempMem := HndTopics.GetTopicContent(aTopicList[iCounter].Id);

          HndEditor.Clear(oEditor);
          HndEditor.SetContent(oEditor,oTempMem);

          sHtmlStr := HndEditor.GetContentAsHtml(oEditor,cssOutput); // user html
          sHtmlStr := StringReplace(
          sHtmlTemplateStr,
          userLib_Bodymark,sHtmlStr,[rfReplaceAll]);

          sFileContent := sFileContent +
          '<div id="topic_content">'   + #13#10 + sHtmlTemplateStr + #13#10;

          sFileContent := sFileContent +
          '</div>' + #13#10;

          if nFooterKind <> 2 then
          begin
            sFileContent := sFileContent       +
            '<div id="topic_footer">'          + #13#10 +
            '<div id="topic_footer_content">'  + #13#10 +
            HTMLEncode(sTopicFooter)           + #13#10 +
            '</div>'                           + #13#10 +
            '</div>'                           + #13#10 ;
          end;

          sFileContent := sFileContent +
          '<div id="custom_footer">'   + #13#10 +
          GetTemplateHtmlFooter()      + #13#10 +
          '</div>'                     + #13#10 +
          GetCustomJs()                + #13#10 ;

          sFileContent := sFileContent +
          '</body>' + #13#10 +
          '</html>' + #13#10 ;

          // ------------------------------
          // write the topic.html file ...
          // ------------------------------
          oFileNameList := TStringList.Create;
          oFileNameList.WriteBOM := false;
          oFileNameList.Add(sFileContent);
          oFileNameList.SaveToFile(
          sProjectFolder +
          HndTopics.GetTopicCaption(
          HndGeneratorInfo.CurrentTopic) + '.html');
        end;
      end;

      // -----------------------------------------------
      // at the end, we hold a notice of last editing...
      // -----------------------------------------------
      sRootTopicID := HndTopics.GetProjectTopic();
      HndTopicsProperties.SetTopicCustomPropertyValue(sRootTopicId,
      'Last HTML Generation',
      FormatDateTime('yyyy-mm-dd hh:nn:ss', Now));

    except
      on E: Exception do
      begin
        ShowMessage('Exception:' + #13#10 +
        E.Message);
      end;
    end;
  finally
    // ---------------------------
    // clear, and free objects ...
    // ---------------------------
    if Assigned(oTempMem) then
    begin
      oTempMem.Clear;
      oTempMem.Free;
    end;

    if Assigned(oFileNameList) then
    begin
      oFileNameList.Clear;
      oFileNameList.Free;
    end;

    HndEditor.DestroyTemporaryEditor(oEditorTemp);
    HndEditor.DestroyTemporaryEditor(oEditor);
  end;
end.
