// lib/data/content/themes/theme_sentences.dart
// Drama-style learning sentences for each theme (8 sentences × 6 themes = 48 total)

class ThemeSentence {
  final String theme;       // 'kdrama', 'kpop', 'travel', 'kfood', 'manners', 'slang'
  final int level;          // 1-6
  final String korean;      // Full Korean sentence (drama-style, natural)
  final String english;     // English translation
  final List<String> targetWords; // Key words to learn from this sentence
  final String context;     // Situation context
  final String grammar;     // Grammar point used

  const ThemeSentence({
    required this.theme,
    required this.level,
    required this.korean,
    required this.english,
    required this.targetWords,
    required this.context,
    required this.grammar,
  });
}

// ─────────────────────────────────────────────────────────────
// KDRAMA — 8 sentences (levels 1–6)
// ─────────────────────────────────────────────────────────────
const List<ThemeSentence> kdramaSentences = [
  ThemeSentence(
    theme: 'kdrama',
    level: 1,
    korean: '오빠, 나 보고 싶었어?',
    english: 'Oppa, did you miss me?',
    targetWords: ['오빠', '보고 싶다'],
    context: 'A girl greets her older brother or boyfriend after time apart',
    grammar: '-았/었어?',
  ),
  ThemeSentence(
    theme: 'kdrama',
    level: 1,
    korean: '울지 마. 내가 항상 여기 있을게.',
    english: "Don't cry. I will always be here.",
    targetWords: ['울다', '항상', '여기', '있다'],
    context: 'A character comforts someone who is crying',
    grammar: '-(으)ㄹ게',
  ),
  ThemeSentence(
    theme: 'kdrama',
    level: 2,
    korean: '사랑한다고 말해줘. 한 번만.',
    english: 'Tell me that you love me. Just once.',
    targetWords: ['사랑하다', '말하다', '한 번'],
    context: 'Emotional confession scene — one character pleads with another',
    grammar: '-다고 말하다',
  ),
  ThemeSentence(
    theme: 'kdrama',
    level: 2,
    korean: '너를 처음 봤을 때부터 좋아했어.',
    english: 'I liked you from the first moment I saw you.',
    targetWords: ['처음', '봤을 때', '좋아하다'],
    context: 'A character confesses that their feelings started from the very beginning',
    grammar: '-(으)ㄹ 때부터',
  ),
  ThemeSentence(
    theme: 'kdrama',
    level: 3,
    korean: '우리가 다시 만날 수 있을까?',
    english: 'Do you think we can meet again?',
    targetWords: ['다시', '만나다', '수 있다'],
    context: 'Tearful goodbye scene at an airport or bus terminal',
    grammar: '-(으)ㄹ까?',
  ),
  ThemeSentence(
    theme: 'kdrama',
    level: 3,
    korean: '네가 곁에 있어서 버틸 수 있었어.',
    english: 'Because you were by my side, I could endure.',
    targetWords: ['곁', '있다', '버티다'],
    context: 'A character thanks someone for being their emotional support',
    grammar: '-아/어서',
  ),
  ThemeSentence(
    theme: 'kdrama',
    level: 4,
    korean: '지금 이 순간을 영원히 기억할게.',
    english: 'I will remember this moment forever.',
    targetWords: ['순간', '영원히', '기억하다'],
    context: 'A romantic moment under the stars — a promise to never forget',
    grammar: '-(으)ㄹ게',
  ),
  ThemeSentence(
    theme: 'kdrama',
    level: 5,
    korean: '이렇게 될 줄은 꿈에도 몰랐어.',
    english: 'I never even dreamed it would turn out like this.',
    targetWords: ['이렇게', '되다', '꿈에도', '모르다'],
    context: 'A character reflects on an unexpected turn of events — shock or disbelief',
    grammar: '-(으)ㄹ 줄 모르다',
  ),
];

// ─────────────────────────────────────────────────────────────
// KPOP — 8 sentences (levels 1–6)
// ─────────────────────────────────────────────────────────────
const List<ThemeSentence> kpopSentences = [
  ThemeSentence(
    theme: 'kpop',
    level: 1,
    korean: '이 노래 정말 좋아!',
    english: 'I really love this song!',
    targetWords: ['노래', '정말', '좋다'],
    context: 'A fan hears a new track for the first time',
    grammar: '-아/어요',
  ),
  ThemeSentence(
    theme: 'kpop',
    level: 1,
    korean: '오늘 콘서트 완전 대박이었어!',
    english: 'Tonight\'s concert was totally amazing!',
    targetWords: ['콘서트', '완전', '대박'],
    context: 'A fan texts a friend right after a concert ends',
    grammar: '-았/었어',
  ),
  ThemeSentence(
    theme: 'kpop',
    level: 2,
    korean: '저는 아이돌 춤을 따라 추는 걸 좋아해요.',
    english: 'I love following along with idol dances.',
    targetWords: ['아이돌', '춤', '따라 추다'],
    context: 'Someone explains their hobby to a new friend',
    grammar: '-는 걸 좋아하다',
  ),
  ThemeSentence(
    theme: 'kpop',
    level: 2,
    korean: '그 그룹 새 앨범 들어봤어? 진짜 미쳤어.',
    english: 'Have you listened to that group\'s new album? It\'s insane.',
    targetWords: ['그룹', '앨범', '들어보다', '미치다'],
    context: 'Two fans talk excitedly about a new release',
    grammar: '-아/어 보다',
  ),
  ThemeSentence(
    theme: 'kpop',
    level: 3,
    korean: '그 곡은 들을수록 더 좋아지는 것 같아.',
    english: 'The more I listen to that song, the more I seem to like it.',
    targetWords: ['곡', '들을수록', '좋아지다'],
    context: 'A listener discovers that a song is a slow-burn favourite',
    grammar: '-(으)ㄹ수록',
  ),
  ThemeSentence(
    theme: 'kpop',
    level: 3,
    korean: '그 멤버가 탈퇴한다고 해서 팬들이 충격받았어.',
    english: 'Because they said that member is leaving, fans were shocked.',
    targetWords: ['멤버', '탈퇴하다', '팬', '충격받다'],
    context: 'News breaks about a member departure — fan community reacts',
    grammar: '-다고 하다',
  ),
  ThemeSentence(
    theme: 'kpop',
    level: 4,
    korean: '그 뮤직비디오는 볼 때마다 눈물이 나.',
    english: 'Every time I watch that music video, I tear up.',
    targetWords: ['뮤직비디오', '볼 때마다', '눈물이 나다'],
    context: 'A fan describes an emotionally powerful music video',
    grammar: '-(으)ㄹ 때마다',
  ),
  ThemeSentence(
    theme: 'kpop',
    level: 5,
    korean: '그들의 음악이 내 힘든 시절을 버티게 해줬어.',
    english: 'Their music helped me get through the hard times.',
    targetWords: ['음악', '힘들다', '시절', '버티다', '해주다'],
    context: 'A fan writes a heartfelt letter explaining what the group means to them',
    grammar: '-게 해주다',
  ),
];

// ─────────────────────────────────────────────────────────────
// TRAVEL — 8 sentences (levels 1–6)
// ─────────────────────────────────────────────────────────────
const List<ThemeSentence> travelSentences = [
  ThemeSentence(
    theme: 'travel',
    level: 1,
    korean: '화장실이 어디예요?',
    english: 'Where is the bathroom?',
    targetWords: ['화장실', '어디', '이다'],
    context: 'A tourist urgently needs the restroom in a public place',
    grammar: '-이에요/예요',
  ),
  ThemeSentence(
    theme: 'travel',
    level: 1,
    korean: '지하철역이 여기서 멀어요?',
    english: 'Is the subway station far from here?',
    targetWords: ['지하철역', '여기서', '멀다'],
    context: 'A visitor asks a local for directions on the street',
    grammar: '-아/어요?',
  ),
  ThemeSentence(
    theme: 'travel',
    level: 2,
    korean: '이거 얼마예요? 깎아 주실 수 있어요?',
    english: 'How much is this? Can you give me a discount?',
    targetWords: ['얼마', '깎다', '주다'],
    context: 'Bargaining at a traditional market stall',
    grammar: '-(으)ㄹ 수 있다',
  ),
  ThemeSentence(
    theme: 'travel',
    level: 2,
    korean: '이 버스 경복궁에 가요?',
    english: 'Does this bus go to Gyeongbokgung Palace?',
    targetWords: ['버스', '경복궁', '가다'],
    context: 'A tourist double-checks the bus route at a stop',
    grammar: '-아/어요?',
  ),
  ThemeSentence(
    theme: 'travel',
    level: 3,
    korean: '서울에 처음 왔는데, 꼭 가봐야 할 곳이 어디예요?',
    english: 'It\'s my first time in Seoul — where must I go?',
    targetWords: ['처음', '꼭', '가보다', '곳'],
    context: 'A first-time visitor asks a local for recommendations',
    grammar: '-아/어야 하다',
  ),
  ThemeSentence(
    theme: 'travel',
    level: 3,
    korean: '여기 전통 시장에서 파는 음식이 맛있기로 유명하다고 들었어요.',
    english: 'I heard this traditional market is famous for its delicious food.',
    targetWords: ['전통 시장', '유명하다', '듣다'],
    context: 'A traveller shares what they read before arriving',
    grammar: '-다고 듣다',
  ),
  ThemeSentence(
    theme: 'travel',
    level: 4,
    korean: '짐을 잃어버리는 바람에 하루 종일 공항에 있었어요.',
    english: 'Because I lost my luggage, I was at the airport all day.',
    targetWords: ['짐', '잃어버리다', '하루 종일', '공항'],
    context: 'A traveller recounts an unfortunate airport mishap',
    grammar: '-는 바람에',
  ),
  ThemeSentence(
    theme: 'travel',
    level: 5,
    korean: '이 골목을 걷다 보면 마치 조선 시대로 돌아간 것 같아요.',
    english: 'As you walk through this alley, it feels as if you have returned to the Joseon era.',
    targetWords: ['골목', '걷다 보면', '조선 시대', '돌아가다'],
    context: 'A guide describes the atmosphere of a historic neighbourhood',
    grammar: '-다 보면',
  ),
];

// ─────────────────────────────────────────────────────────────
// KFOOD — 8 sentences (levels 1–6)
// ─────────────────────────────────────────────────────────────
const List<ThemeSentence> kfoodSentences = [
  ThemeSentence(
    theme: 'kfood',
    level: 1,
    korean: '이거 진짜 맛있다! 또 먹고 싶어.',
    english: 'This is so delicious! I want to eat it again.',
    targetWords: ['맛있다', '또', '먹다', '싶다'],
    context: 'Someone tries Korean food for the first time and is blown away',
    grammar: '-고 싶다',
  ),
  ThemeSentence(
    theme: 'kfood',
    level: 1,
    korean: '매운 거 괜찮아요? 이 떡볶이 정말 매워요.',
    english: 'Are you okay with spicy food? This tteokbokki is really spicy.',
    targetWords: ['맵다', '떡볶이', '괜찮다'],
    context: 'A Korean friend warns a foreigner before ordering tteokbokki',
    grammar: '-아/어요',
  ),
  ThemeSentence(
    theme: 'kfood',
    level: 2,
    korean: '삼겹살에 소주 한 잔 어때요?',
    english: 'How about a glass of soju with samgyeopsal?',
    targetWords: ['삼겹살', '소주', '어때요'],
    context: 'A colleague suggests going out for a Korean BBQ dinner after work',
    grammar: '-(으)ㄹ까요',
  ),
  ThemeSentence(
    theme: 'kfood',
    level: 2,
    korean: '된장찌개는 따뜻하고 구수해서 겨울에 딱이에요.',
    english: 'Doenjang-jjigae is warm and savory, perfect for winter.',
    targetWords: ['된장찌개', '따뜻하다', '구수하다', '딱이다'],
    context: 'Someone explains why Korean stew is the ultimate winter comfort food',
    grammar: '-아/어서',
  ),
  ThemeSentence(
    theme: 'kfood',
    level: 3,
    korean: '먹어 봤자 익숙하지 않으면 맛을 모를 수도 있어요.',
    english: 'Even if you try it, you might not appreciate the taste if you\'re not used to it.',
    targetWords: ['익숙하다', '맛', '알다', '-ㄹ 수도 있다'],
    context: 'A discussion about acquiring a taste for fermented Korean foods',
    grammar: '-아/어 봤자',
  ),
  ThemeSentence(
    theme: 'kfood',
    level: 3,
    korean: '이 집 냉면은 먹을수록 빠져드는 맛이에요.',
    english: 'This restaurant\'s naengmyeon has a taste that draws you in the more you eat.',
    targetWords: ['냉면', '먹을수록', '빠져들다'],
    context: 'A food blogger describes their favourite naengmyeon spot',
    grammar: '-(으)ㄹ수록',
  ),
  ThemeSentence(
    theme: 'kfood',
    level: 4,
    korean: '처음에는 김치 냄새가 낯설었는데, 이제는 없으면 허전해요.',
    english: 'At first the smell of kimchi was unfamiliar, but now I feel empty without it.',
    targetWords: ['냄새', '낯설다', '허전하다', '없으면'],
    context: 'A foreigner describes how kimchi became an essential part of their diet',
    grammar: '-(으)ㄴ데 이제는',
  ),
  ThemeSentence(
    theme: 'kfood',
    level: 5,
    korean: '한국의 식문화는 단순히 먹는 것을 넘어 함께 나누는 정을 중시해요.',
    english: 'Korean food culture goes beyond simply eating — it values sharing and warmth.',
    targetWords: ['식문화', '넘다', '나누다', '정', '중시하다'],
    context: 'A cultural essay explaining the communal philosophy behind Korean meals',
    grammar: '-(으)ㄹ 뿐만 아니라',
  ),
];

// ─────────────────────────────────────────────────────────────
// MANNERS — 8 sentences (levels 1–6)
// ─────────────────────────────────────────────────────────────
const List<ThemeSentence> mannersSentences = [
  ThemeSentence(
    theme: 'manners',
    level: 1,
    korean: '안녕하세요, 처음 뵙겠습니다.',
    english: 'Hello, it\'s nice to meet you for the first time.',
    targetWords: ['안녕하세요', '처음', '뵙다'],
    context: 'A formal first introduction — bowing and greeting a new colleague',
    grammar: '-겠습니다',
  ),
  ThemeSentence(
    theme: 'manners',
    level: 1,
    korean: '잘 먹겠습니다!',
    english: 'I will eat well! (said before a meal)',
    targetWords: ['잘', '먹다', '-겠습니다'],
    context: 'Essential phrase said before every meal in Korean culture',
    grammar: '-겠습니다',
  ),
  ThemeSentence(
    theme: 'manners',
    level: 2,
    korean: '어른한테는 두 손으로 드려야 해요.',
    english: 'You must give things to elders with both hands.',
    targetWords: ['어른', '두 손', '드리다'],
    context: 'A parent teaches a child about Korean respectful etiquette',
    grammar: '-아/어야 하다',
  ),
  ThemeSentence(
    theme: 'manners',
    level: 2,
    korean: '어른이 드실 때까지 기다리는 게 예의예요.',
    english: 'It\'s polite to wait until elders start eating.',
    targetWords: ['어른', '드시다', '기다리다', '예의'],
    context: 'Explaining Korean dining etiquette to a foreign guest',
    grammar: '-는 게 예의예요',
  ),
  ThemeSentence(
    theme: 'manners',
    level: 3,
    korean: '처음 만나는 분께 나이를 여쭤보는 건 자연스러운 일이에요.',
    english: 'It\'s natural to ask someone\'s age when you first meet in Korea.',
    targetWords: ['처음 만나다', '나이', '여쭤보다', '자연스럽다'],
    context: 'Explaining to a foreigner why Koreans ask ages right away',
    grammar: '-는 건 자연스럽다',
  ),
  ThemeSentence(
    theme: 'manners',
    level: 3,
    korean: '선배님께 먼저 인사를 드리는 게 한국 직장 문화예요.',
    english: 'Greeting your senior colleagues first is Korean workplace culture.',
    targetWords: ['선배', '먼저', '인사 드리다', '직장 문화'],
    context: 'Explaining hierarchy and greetings in a Korean office setting',
    grammar: '-는 게 N이다',
  ),
  ThemeSentence(
    theme: 'manners',
    level: 4,
    korean: '아무리 친해도 공공장소에서 큰 소리로 �騒들면 안 돼요.',
    english: 'No matter how close you are, making loud noise in public is not okay.',
    targetWords: ['아무리', '공공장소', '떠들다', '안 되다'],
    context: 'A reminder about public conduct and keeping noise levels down in Korea',
    grammar: '아무리 -아/어도',
  ),
  ThemeSentence(
    theme: 'manners',
    level: 5,
    korean: '빈손으로 방문하는 것보다 작은 선물이라도 가져가는 편이 낫습니다.',
    english: 'It is better to bring even a small gift than to visit empty-handed.',
    targetWords: ['빈손', '방문하다', '선물', '-이라도', '낫다'],
    context: 'Explaining Korean gift-giving etiquette when visiting someone\'s home',
    grammar: '-(으)ㄹ지라도',
  ),
];

// ─────────────────────────────────────────────────────────────
// SLANG — 8 sentences (levels 1–6)
// ─────────────────────────────────────────────────────────────
const List<ThemeSentence> slangSentences = [
  ThemeSentence(
    theme: 'slang',
    level: 1,
    korean: '대박! 이게 진짜야?',
    english: 'Wow! Is this real? (That\'s insane!)',
    targetWords: ['대박', '진짜'],
    context: 'A friend reacts with disbelief at some crazy good news',
    grammar: '-이야?',
  ),
  ThemeSentence(
    theme: 'slang',
    level: 1,
    korean: '헐, 나 완전 망했어.',
    english: 'Oh no, I\'m totally done for.',
    targetWords: ['헐', '완전', '망하다'],
    context: 'A student realises they forgot to submit homework',
    grammar: '-았/었어',
  ),
  ThemeSentence(
    theme: 'slang',
    level: 2,
    korean: '야, 그 사람 진짜 꿀잼이다.',
    english: 'Dude, that person is seriously hilarious.',
    targetWords: ['야', '꿀잼', '이다'],
    context: 'Two friends watch a funny video together',
    grammar: '-이다',
  ),
  ThemeSentence(
    theme: 'slang',
    level: 2,
    korean: '오늘 너무 핵노잼이었어. 집에 일찍 왔어.',
    english: 'Today was super boring. I came home early.',
    targetWords: ['핵노잼', '일찍', '오다'],
    context: 'A friend complains about a dull event they attended',
    grammar: '-았/었어',
  ),
  ThemeSentence(
    theme: 'slang',
    level: 3,
    korean: '그 사람 인싸인지 아싸인지 모르겠어.',
    english: 'I can\'t tell if that person is an insider or an outsider.',
    targetWords: ['인싸', '아싸', '모르다'],
    context: 'Discussing whether someone is socially popular or a loner',
    grammar: '-인지 모르다',
  ),
  ThemeSentence(
    theme: 'slang',
    level: 3,
    korean: '고구마 같은 상황이어서 답답해 미치겠어.',
    english: 'The situation is so frustrating and stuffy, I\'m going crazy.',
    targetWords: ['고구마', '답답하다', '-아/어 미치겠다'],
    context: 'Venting about a situation that feels painfully slow or blocked',
    grammar: '-아/어 미치겠다',
  ),
  ThemeSentence(
    theme: 'slang',
    level: 4,
    korean: '걔는 TMI를 너무 많이 공유하는 편이야.',
    english: 'That person tends to share way too much information.',
    targetWords: ['TMI', '공유하다', '-는 편이다'],
    context: 'Describing someone who overshares personal details in conversation',
    grammar: '-는 편이다',
  ),
  ThemeSentence(
    theme: 'slang',
    level: 5,
    korean: '요즘 MZ세대 사이에서 유행하는 표현들을 이해 못 하면 아재 소리 들어.',
    english: 'If you can\'t understand the trendy expressions among Gen MZ these days, people will call you old.',
    targetWords: ['MZ세대', '유행하다', '표현', '아재'],
    context: 'A discussion about generational language gaps and keeping up with slang',
    grammar: '-으면 N 소리 듣다',
  ),
];

// ─────────────────────────────────────────────────────────────
// All theme sentences combined
// ─────────────────────────────────────────────────────────────
const List<ThemeSentence> kAllThemeSentences = [
  ...kdramaSentences,
  ...kpopSentences,
  ...travelSentences,
  ...kfoodSentences,
  ...mannersSentences,
  ...slangSentences,
];

List<ThemeSentence> getThemeSentences(String theme) =>
    kAllThemeSentences.where((s) => s.theme == theme).toList();

List<ThemeSentence> getThemeSentencesByLevel(String theme, int level) =>
    kAllThemeSentences.where((s) => s.theme == theme && s.level == level).toList();
