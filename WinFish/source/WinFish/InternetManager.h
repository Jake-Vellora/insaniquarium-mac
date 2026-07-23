#ifndef __INTERNETMGR_H__
#define __INTERNETMGR_H__
#include <list>
#include <SexyAppFramework/HTTPTransfer.h>

namespace Sexy
{
	class HTTPTransfer;
	#define MAX_HTTP_TRANSFERS 4

	class InternetManager 
	{
	public:
		int m0x04;
		HTTPTransfer mUpdateTransfer;
		HTTPTransfer mHTTPTransfers[MAX_HTTP_TRANSFERS];
		bool m0x508;
		bool mUpToDate;
		bool m0x50a;
		SexyString mUpdateURL;
		std::list<SexyString> mList1;
		std::list<SexyString> mList2;
		std::list<SexyString> mAdUrlList;

	public:
		InternetManager();
		virtual ~InternetManager();

		void					Update();
		bool					CheckForUpdates();
		bool					IsUpToDate();
		void					StartAdLoading();
		void					StartUpdateCheck(SexyString aReqUrl);

		SexyString				GetUpdateURL();
		int						GetUpdateResultCode();

		void					ReadAdList();
		void					CleanAdList();
		void					Unk01();
	};
}

#endif
