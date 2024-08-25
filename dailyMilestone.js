import fetch from 'node-fetch';

export const dailyMilestone = async (auth, stage) => {
    let success = false;
    while (!success) {
        try {
            await fetch('https://odyssey-api.sonic.game/user/transactions/state/daily', {
                method: 'GET',
                headers: {
                    'accept': '*/*',
                    'accept-language': 'en-US,en;q=0.7',
                    'content-type': 'application/json',
                    'authorization': auth
                }
            });

            const response = await fetch('https://odyssey-api.sonic.game/user/transactions/rewards/claim', {
                method: 'POST',
                headers: {
                    'accept': '*/*',
                    'accept-language': 'en-US,en;q=0.7',
                    'content-type': 'application/json',
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
            await new Promise(resolve => setTimeout(resolve, 5000)); // 5초 대기 후 재시도
        }
    }
};
