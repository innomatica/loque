// app info
const appId = 'com.innomatic.loqueapp';
const appName = 'Loque';
const appVersion = '1.3.3+35';
const emailDeveloper = 'nuntium.ubique@gmail.com';

// asset images
const playStoreUrlQrCode = 'assets/images/com.innomatic.loqueapp.png';

// urls
const urlGooglePlay = 'https://play.google.com/store/apps/details?id=$appId';
const urlAppStore = null;
const urlHomePage = 'https://www.innomatic.ca';
const urlSourceRepo = 'https://github.com/innomatica/loque';
const urlPrivacyPolicy = 'https://innomatica.github.io/loque/privacy/';
const urlDisclaimer = 'https://innomatica.github.io/loque/disclaimer/';
const urlInstruction = 'https://innomatica.github.io/loque/manual/';
const urlAppIconSource = 'https://www.flaticon.com/free-icons/podcast';
const urlStoreImageSource =
    'https://www.pexels.com/photo/rode-podmic-audio-microphone-in-a-podcast-studio-11884525/';
const urlCuratedData =
    'https://raw.githubusercontent.com/innomatica/loque/master/extra/data/curated.json';

// github
const githubUser = 'innomatica';
const githubRepo = 'loque';

// sleep timer setting
const sleepTimeouts = [30, 20, 10, 5, 60];

// shared pref keys
const spKeyPlayListIds = 'plistids';
const spKeyMaxSearchResults = 'maxsearch';
const spKeyTrendingDaysSince = 'trdayssince';
const spKeyDataRetentionPeriod = 'dataretention';
const spKeySearchEngine = 'searchengine';

// default parameters
const defaultMaxSearchResults = 100;
const defaultTrendingDaysSince = 360;
const defaultDataRetentionPeriod = 30;
const defaultSearchEngine = 'DuckDuckGo';

// options
const maxSearchResultsSelection = [10, 50, 100, 200];
const dataRetentionPeriodSelection = [7, 14, 30, 90];
const maxDataRetentionPeriod = 90;
const searchEngineSelection = ['DuckDuckGo', 'Google', 'Bing'];
const swipeGestureThreshold = 50;
