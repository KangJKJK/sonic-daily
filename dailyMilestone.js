import fetch from 'node-fetch';

const defaultHeaders = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.7',
    'content-type': 'application/json',
    'priority': 'u=1, i',
    'sec-ch-ua': '"Not/A)Brand";v="8", "Chromium";v="126", "Brave";v="126"',
    'sec-ch-ua-mobile': '?0',
    'sec-ch-ua-platform': '"Windows"',
    'sec-fetch-dest': 'empty',
    'sec-fetch-mode': 'cors',
    'sec-fetch-site': 'same-site',
    'sec-gpc': '1',
    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
};

const MAX_RETRIES = 5; // 최대 재시도 횟수

export const dailyMilestone = async (auth, stage) => {
    let success = false;
    let retries = 0; // 재시도 횟수

    while (!success && retries < MAX_RETRIES) {
        try {
            // 상태 확인
            await fetch('https://odyssey-api.sonic.game/user/transactions/state/daily', {
                method: 'GET',
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                }
            });

            // 보상 클레임 요청
            const response = await fetch('https://odyssey-api.sonic.game/user/transactions/rewards/claim', {
                method: 'POST',
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                },
                body: JSON.stringify({ 'stage': stage })
            });

            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const text = await response.text();
            try {
                const data = JSON.parse(text);
                if (data.message === 'interact rewards already claimed') {
                    success = true;
                    return `마일스톤 ${stage} 이미 클레임했습니다!`;
                }
                if (data.data) {
                    success = true;
                    return `성공적으로 마일스톤 ${stage} 보상을 클레임했습니다.`;
                }
            } catch (e) {
                throw new Error('응답이 JSON 형식이 아닙니다.');
            }
        } catch (e) {
            console.error('일일 마일스톤 클레임 오류:', e.message);
            retries += 1; // 재시도 횟수 증가
            if (retries >= MAX_RETRIES) {
                return '최대 재시도 횟수를 초과했습니다. 다음 단계로 넘어갑니다.';
            }
            await new Promise(resolve => setTimeout(resolve, 5000)); // 5초 대기 후 재시도
        }
    }

    if (!success) {
        return '일일 마일스톤 클레임 실패. 다음 단계로 넘어갑니다.';
    }
};
