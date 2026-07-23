#include <SexyAppFramework/Common.h>
#include "SexyApp.h"

#include "SEHCatcher.h"
#include "Common.h"
#include <time.h>
#include <fstream>

using namespace Sexy;

SexyApp* Sexy::gSexyApp = NULL;

// Groups of 80-byte data
const char DYNAMIC_DATA_BLOCK[400] = 
	"DYN00000PACPOPPOPCAPPACPOPPOPCAPBUILDINFOMARKERPACPOPPOPCAPPACPOPPOPCAPXXXXXXXXX"
	"00000000PACPOPPOPCAPPACPOPPOPCAPBUILDINFOMARKERPACPOPPOPCAPPACPOPPOPCAPXXXXXXXXX";
									
const char* BUILD_INFO_MARKER		= DYNAMIC_DATA_BLOCK + 80;
const char* SIGNATURE_CODE_MARKER	= DYNAMIC_DATA_BLOCK + 80*2;
const char* BETA_ID_MARKER			= DYNAMIC_DATA_BLOCK + 80*3;

SexyApp::SexyApp()
{
	gSexyApp = this;

	mTimesPlayed = 0;
	mTimesExecuted = 0;
	mTimedOut = false;

	mIsRegistered = false;
	mBuildUnlocked = false;
	mDownloadId = 0;
	mRegSource = "ingame";
	mSkipAd = false;
	mDontUpdate = false;
	mLastVerCheckQueryTime = 0;

	mDemoPrefix = "popcap";
	mDemoFileName = mDemoPrefix + ".dmo";	
	mCompanyName = "PopCap";

	mInternetManager = nullptr;//new InternetManager();
	mBetaSupport = NULL;
	//mBetaValidate = false;

	// In-app updater strings. The port points the update check at our GitHub
	// release feed; several of these keys were referenced but never defined
	// upstream (they resolved to empty), so define them all here.
	SetString("UPDATE_CHECK_TITLE", "Check for Updates");
	SetString("UPDATE_CHECK_BODY",  "Checking for updates to Insaniquarium ...");
	SetString("UP_TO_DATE_TITLE",   "Up to Date");
	SetString("UP_TO_DATE_BODY",    "You have the latest version of Insaniquarium.");
	SetString("NEW_VERSION_TITLE",  "Update Available");
	SetString("NEW_VERSION_BODY",   "A new version of Insaniquarium is available. Download and install it now? The game will restart automatically.");

	char aStr[9] = {0};
	strncpy(aStr, BUILD_INFO_MARKER, 8);
	mBuildNum = atoi(aStr);

	if (mBuildNum != 0)
		mBuildDate = BUILD_INFO_MARKER + 8;
}

SexyApp::~SexyApp()
{
	//delete mBetaSupport;
	//delete mInternetManager;
}

/*
bool SexyApp::Validate(const std::string& theUserName, const std::string& theRegCode)
{
	BigInt n("42BF94023BBA6D040C8B81D9");
	BigInt e("11");

	ulong i;
	std::string aDataString;
	bool space = false;	
	for (i = 0; i < theUserName.size(); i++)
	{
		if (theUserName[i] == ' ')
		{
			if (aDataString.length() > 0)
				space = true;
		}
		else
		{
			if (space)
			{
				aDataString += " ";
				space = false;
			}

			char aChar = theUserName[i];
			for (int j = 0; gRegKeyTranslationTable[j][0] != 0; j++)
				if (gRegKeyTranslationTable[j][0] == aChar)
					aChar = gRegKeyTranslationTable[j][1];

			aDataString += toupper(aChar);
		}
	}

	std::string aProduct;
	aProduct = mProdName;
	for (i = 0; i < aProduct.length(); i++)
		aProduct[i] = toupper(aProduct[i]);

	aDataString += "\n";
	aDataString += aProduct;
	BigInt aHash = HashString(aDataString, 94);	
	
	BigInt aSignature = KeyToInt(theRegCode);
	BigInt aHashTest = aSignature.ModPow(e, n);

	return aHashTest == aHash;
}
*/

void SexyApp::ReadFromRegistry()
{
	SexyAppBase::ReadFromRegistry();

	if (!mPlayingDemoBuffer)
	{
		mTimesPlayed = 0;
		mTimesExecuted = 0;

		char aFileName[256] = {};
        // !PORT
		//GetWindowsDirectory(aFileName, 256);
		//if (aFileName[strlen(aFileName)-1] != '\\')
		//	strcat(aFileName, "\\");
		strcat(aFileName, "popcinfo.dat");

		FILE* fp = fopen(aFileName, "rb");
		if (fp != NULL)
		{
			for (;;)
			{
				ushort aLen;
				if (fread(&aLen, 1, sizeof(short), fp) == 0)
					break;

				if (aLen < 256)
				{
					char aProdName[256];
					aProdName[aLen] = '\0';
					fread(aProdName, aLen, sizeof(char), fp);

					if (strcmp(aProdName, mProdName.c_str()) == 0)
					{
						short aShort;
						fread(&aShort, 1, sizeof(short), fp);
						mTimesPlayed = aShort;

						fread(&aShort, 1, sizeof(short), fp);
						mTimesExecuted = aShort;

						break;
					}
				}

				fseek(fp, sizeof(int), SEEK_CUR);
			}
			fclose(fp);
		}
	}

	RegistryReadString("ReferId", &mReferId);
	mReferId = GetString("ReferId", mReferId);
	mRegisterLink = "http://www.popcap.com/register.php?theGame=" + mProdName + "&referid=" + mReferId;	
	RegistryReadString("RegisterLink", &mRegisterLink);

	int anInt;

	if (RegistryReadInteger("DontUpdate", &anInt))
		mDontUpdate = anInt != 0;

	if (RegistryReadInteger("DownloadId", &anInt))
		mDownloadId = anInt;

	RegistryReadString("Variation", &mVariation);

	if (RegistryReadInteger("TimesPlayed", &anInt))
	{
		if (!mPlayingDemoBuffer)
		{
			if (mTimesPlayed != anInt)
				mTimesPlayed = 100;
		}
		else
		{
			mTimesPlayed = anInt;
		}
	}

	if (RegistryReadInteger("TimesExecuted", &anInt))
	{
		if (!mPlayingDemoBuffer)
		{
			if (mTimesExecuted != anInt)
				mTimesExecuted = 100;
		}
		else
		{
			mTimesExecuted = anInt;
		}
	}
	
	if (RegistryReadInteger("LastVerCheckQueryTime", &anInt))
	{
		mLastVerCheckQueryTime = anInt;
	}
	else
	{
		time_t aTimeNow;
		time(&aTimeNow);

		mLastVerCheckQueryTime = aTimeNow;
	}

	if (RegistryReadString("RegName", &mRegUserName))
		mUserName = mRegUserName;
	
	RegistryReadString("RegCode", &mRegCode);		

	mIsRegistered |= true /*Validate(mRegUserName, mRegCode)*/;	

	// Override registry values with partner.xml values
	mRegisterLink = GetString("RegisterLink", mRegisterLink);
	mDontUpdate = GetBoolean("DontUpdate", mDontUpdate);
	// The port originally shipped DontUpdate=true to hide the then-dead PopCap
	// update system. It's alive again (repointed at our GitHub release feed), so
	// force it on: this un-hides the Options "Check Updates" button and lets the
	// weekly auto-prompt fire.
	mDontUpdate = false;
}

void SexyApp::WriteToRegistry()
{
	SexyAppBase::WriteToRegistry();

	if (!mPlayingDemoBuffer)
	{
		char aFileName[256] = {};
        // !PORT
		//GetWindowsDirectory(aFileName, 256);
		//if (aFileName[strlen(aFileName)-1] != '\\')
		//	strcat(aFileName, "\\");
		strcat(aFileName, "popcinfo.dat");

		FILE* fp = fopen(aFileName, "r+b");
		if (fp != NULL)
		{
			for (;;)
			{
				ushort aLen;
				if (fread(&aLen, 1, sizeof(short), fp) == 0)
					break;

				if (aLen < 256)
				{
					char aProdName[256];
					aProdName[aLen] = '\0';
					fread(aProdName, aLen, sizeof(char), fp);

					if (strcmp(aProdName, mProdName.c_str()) == 0)
					{
						fseek(fp, -(2 + aLen), SEEK_CUR);
						break;
					}
				}

				fseek(fp, sizeof(int), SEEK_CUR);
			}
		}
		else
			fp = fopen(aFileName, "wb");
			
		if (fp != NULL)
		{
			ushort aLen = mProdName.length();
			fwrite(&aLen, 1, sizeof(short), fp);
			fwrite(mProdName.c_str(), aLen, sizeof(char), fp);

			short aShort = mTimesPlayed;
			fwrite(&aShort, 1, sizeof(short), fp);

			aShort = mTimesExecuted;
			fwrite(&aShort, 1, sizeof(short), fp);

			fclose(fp);
		}
	}

	RegistryWriteInteger("LastVerCheckQueryTime", mLastVerCheckQueryTime);
	RegistryWriteInteger("TimesPlayed", mTimesPlayed);
	RegistryWriteInteger("TimesExecuted", mTimesExecuted);

	// This is for "compatibility"
	if ((mRegUserName.length() == 0) &&
		(mUserName.length() > 0) &&
		(mRegCode.length() > 0))
		mRegUserName = mUserName;

	if (mRegUserName.length() > 0)
		RegistryWriteString("RegName", mRegUserName);

	if (mRegCode.length() > 0)
		RegistryWriteString("RegCode", mRegCode);
}

bool SexyApp::OpenHTMLTemplate(const std::string& theTemplateFile, const DefinesMap& theDefinesMap)
{
	std::fstream anInStream(theTemplateFile.c_str(), std::ios::in);

	if (!anInStream.is_open())
		return false;

    // !PORT
	//WIN32_FIND_DATA aFindData;
	//HANDLE aHandle = FindFirstFile("temp\\tpl*.html", &aFindData);
	//if (aHandle != NULL)
	//{
	//	do
	//	{
	//		std::string aFilePath = std::string("temp\\") + aFindData.cFileName;
	//		DeleteFile(aFilePath.c_str());
	//	}
	//	while (FindNextFile(aHandle, &aFindData));
	//	
	//	FindClose(aHandle);
	//}

	MkDir("temp");

	std::string anOutFilename = StrFormat("temp\\tpl%04d.html", rand()%10000);

	//TODO: A better failover case?
	std::fstream anOutStream(anOutFilename.c_str(), std::ios::out);
	if (!anOutStream.is_open())
		return false;

	char aStr[4096];
	while (!anInStream.eof())
	{
		anInStream.getline(aStr, 4096);
		
		std::string aNewString = Evaluate(aStr, theDefinesMap);

		anOutStream << aNewString.c_str() << std::endl;
	}
	
	return OpenURL(GetFullPath(anOutFilename));
}

bool SexyApp::OpenRegisterPage(DefinesMap theStatsMap)
{
#ifdef ZYLOM
	ZylomGS_StandAlone_ShowBuyPage();
	return true;
#endif

	// Insert standard defines 
	DefinesMap aDefinesMap;
	
	aDefinesMap.insert(DefinesMap::value_type("Src", mRegSource));
	aDefinesMap.insert(DefinesMap::value_type("ProdName", mProdName));
	aDefinesMap.insert(DefinesMap::value_type("Version", mProductVersion));
	aDefinesMap.insert(DefinesMap::value_type("Variation", mVariation));
	aDefinesMap.insert(DefinesMap::value_type("ReferId", mReferId));
	aDefinesMap.insert(DefinesMap::value_type("DownloadId", StrFormat("%d", mDownloadId)));
	aDefinesMap.insert(DefinesMap::value_type("TimesPlayed", StrFormat("%d", mTimesPlayed)));
	aDefinesMap.insert(DefinesMap::value_type("TimesExecuted", StrFormat("%d", mTimesExecuted)));
	aDefinesMap.insert(DefinesMap::value_type("TimedOut", mTimedOut ? "Y" : "N"));

	// Insert game specific stats 
	std::string aStatsString;
	DefinesMap::iterator anItr = theStatsMap.begin();
	while (anItr != theStatsMap.end())
	{
		std::string aKeyString = anItr->first;
		std::string aValueString = anItr->second;

		aStatsString += 
			StrFormat("%04X", aKeyString.length()) + aKeyString + 
			"S" +
			StrFormat("%04X", aValueString.length()) + aValueString;

		++anItr;
	}

	aDefinesMap.insert(DefinesMap::value_type("Stats", aStatsString));

	if (FileExists("register.tpl"))
	{
		return OpenHTMLTemplate("register.tpl", aDefinesMap);
	}
	else
	{
		return OpenURL(mRegisterLink);
	}	
}

bool SexyApp::ShouldCheckForUpdate()
{
	if (mDontUpdate)
		return false;

#ifdef ZYLOM
	return ZylomUpdateCheckNeeded();
#else
	time_t aTimeNow;
	time(&aTimeNow);

	// It is set to 0 if we crash, otherwise ask every week
	return ((mLastVerCheckQueryTime == 0) || 
		(!mLastShutdownWasGraceful) ||
		((mLastVerCheckQueryTime != 0) && 
		(aTimeNow - mLastVerCheckQueryTime > 7*24*60*60)));
#endif
}

void SexyApp::UpdateCheckQueried()
{
	time_t aTimeNow;
	time(&aTimeNow);

	mLastVerCheckQueryTime = aTimeNow;
}

void SexyApp::URLOpenSucceeded(const std::string& theURL)
{
	SexyAppBase::URLOpenSucceeded(theURL);

	if (mShutdownOnURLOpen)
		mSkipAd = true;
}

bool SexyApp::OpenRegisterPage()
{
	DefinesMap aStatsMap;
	return OpenRegisterPage(aStatsMap);
}

/*
bool SexyApp::CheckSignature(const Buffer& theBuffer, const std::string& theFileName)
{
#ifdef _DEBUG
	// Don't check signatures on debug version because it's annoying and the build number
	//  will probably be 0 anyway
	return true;
#endif

	if (mSkipSignatureChecks)
		return true;

	char aSigStr[25];

	FILE* aFP = fopen((theFileName + ".sig").c_str(), "rb");
	if (aFP == NULL)
		return false;

	fread(aSigStr, 1, 24, aFP);
	aSigStr[24] = 0;

	fclose(aFP);

	char* aFileData = new char[theBuffer.GetDataLen()+4];
	int aFileDataPos = 0;
	
	char aStr[9] = {0};
	strncpy(aStr, SIGNATURE_CODE_MARKER, 8);
	int aSignatureCode = atoi(aStr);

	aFileData[aFileDataPos++] = (aSignatureCode & 0xFF);
	aFileData[aFileDataPos++] = ((aSignatureCode >> 8) & 0xFF);
	aFileData[aFileDataPos++] = ((aSignatureCode >> 16) & 0xFF);
	aFileData[aFileDataPos++] = ((aSignatureCode >> 24) & 0xFF);

	theBuffer.SeekFront();
	while (!theBuffer.AtEnd())
	{
		unsigned char c = theBuffer.ReadByte();
		fread(&c, 1, 1, aFP);
		if (!::isspace(c))
			aFileData[aFileDataPos++] = c;
	}	

	// Public RSA stuff
	BigInt n("D99BC76AB7B2578738E606F7");
	BigInt e("11");
			
	BigInt aHash = HashData(aFileData, aFileDataPos, 94);
	delete aFileData;
	
	BigInt aSignature(aSigStr);
	BigInt aHashTest = aSignature.ModPow(e, n);

	return aHashTest == aHash;
}
*/

void SexyApp::PreTerminate()
{
#ifdef ZYLOM
	ZylomShowAd();
#else
	//if ((!mSkipAd) && 
	//	((((!mIsRegistered) || (mInternetManager->HasNewAds())) && ((Rand()%2) == 0))))
	//{
	//	mInternetManager->TryShowAd();
	//}
#endif
}

void SexyApp::OpenUpdateURL()
{
#ifdef ZYLOM
	ZylomGS_StandAlone_ShowUpdatePage();
#else
	//OpenURL(mInternetManager->GetUpdateURL(), true);	
#endif
	Shutdown();
}

void SexyApp::HandleCmdLineParam(const std::string& theParamName, const std::string& theParamValue)
{
	if (theParamName == "-version")
	{
		// Just print version info and then quit
		
		std::string aVersionString = 
			"Product: " + mProdName + "\r\n" +
			"Version: " + mProductVersion + "\r\n" +
			"Build Num: " + StrFormat("%d", mBuildNum) + "\r\n" +
			"Build Date: " + mBuildDate;

		//MessageBox(NULL, aVersionString.c_str(), "Version Info", MB_ICONINFORMATION | MB_OK);
		DoExit(0);
	}
	else
		SexyAppBase::HandleCmdLineParam(theParamName, theParamValue);
}

std::string SexyApp::GetGameSEHInfo()
{
	char aGamesPlayedStr[16];
	sprintf(aGamesPlayedStr, "%d", mTimesPlayed);

	std::string anInfoString = SexyAppBase::GetGameSEHInfo() + 
		"Times Played: " + std::string(aGamesPlayedStr) + "\r\n" +
		"Build Num: " + StrFormat("%d", mBuildNum) + "\r\n" +
		"Build Date: " + mBuildDate + "\r\n";

	if (mReferId.length() != 0)
	{
		anInfoString +=
			"ReferId: " + mReferId + "\r\n";
	}

	return anInfoString;
}

void SexyApp::GetSEHWebParams(DefinesMap* theDefinesMap)
{
	theDefinesMap->insert(DefinesMap::value_type("username", mUserName));
	theDefinesMap->insert(DefinesMap::value_type("buildnum", StrFormat("%d", mBuildNum)));
	theDefinesMap->insert(DefinesMap::value_type("builddate", mBuildDate));
	theDefinesMap->insert(DefinesMap::value_type("referid", mReferId));	
}

void SexyApp::PreDisplayHook()
{
	//if (mBetaValidate && !mBetaSupport->Validate())
	//{
	//	Shutdown();
	//	DoExit(0);
	//	return;
	//}
}

void SexyApp::InitPropertiesHook()
{
	// Load properties if we need to
	bool checkSig = !IsScreenSaver();
	LoadProperties("properties/partner.xml", false, checkSig);

	// Check to see if this build is unlocked.
	if (GetBoolean("NoReg", false))
	{
		mIsRegistered = true;
		mBuildUnlocked = true;
	}

	mProdName = GetString("ProdName", mProdName);
	mIsWindowed = GetBoolean("DefaultWindowed", mIsWindowed);	

	std::string aNewTitle = GetString("Title", "");
	if (aNewTitle.length() > 0)
		mTitle = aNewTitle + " " + mProductVersion;	
		
	//mInternetManager->Init();
	mBetaSupport = nullptr;//new BetaSupport(this);

#ifdef ZYLOM
	LoadProperties();
	ZylomGS_StandAlone_Init(mZylomGameId, (char*) GetString("BUG_REPORT_TITLE").c_str(), (char*) GetString("BUG_REPORT_BODY").c_str());
#endif
}

void SexyApp::Init()
{
	SexyAppBase::Init();

	if (IsScreenSaver())	
		mSkipAd = true;	

	mTimesExecuted++;
}

void SexyApp::UpdateFrames()
{
	SexyAppBase::UpdateFrames();

	//mInternetManager->Update();
}

#ifdef ZYLOM

bool SexyApp::ZylomUpdateCheckNeeded()
{
	return ZylomGS_StandAlone_UpdateCheckNeeded();
}

void SexyApp::ZylomShowAd()
{
	ZylomGS_StandAlone_ShowAd(mIsRegistered);
}

#endif
