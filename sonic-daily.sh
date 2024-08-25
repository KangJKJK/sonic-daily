#!/bin/bash

# 색깔 변수 정의
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

echo -e "${GREEN}Sonic 데일리퀘스트 미션 스크립트를 시작합니다...${NC}"

# 작업 디렉토리 설정
workDir2="/root/sonic-daily"

# 기존 작업 디렉토리가 존재하면 삭제
if [ -d "$workDir2" ]; then
    echo -e "${YELLOW}작업 디렉토리 '${workDir2}'가 이미 존재하므로 삭제합니다.${NC}"
    rm -rf "$workDir2"
fi

# 작업 디렉토리 새로 생성
echo -e "${YELLOW}새로운 작업 디렉토리 '${workDir2}'를 생성합니다.${NC}"
mkdir -p "$workDir2"
cd "$workDir2"

# 파일 다운로드 및 덮어쓰기
echo -e "${YELLOW}필요한 파일들을 다운로드합니다...${NC}"

# 존재하는 파일을 삭제하고 다운로드
rm -f package.json
curl -o package.json https://raw.githubusercontent.com/KangJKJK/sonic-checkin/main/package.json

rm -f package-lock.json
curl -o package-lock.json https://raw.githubusercontent.com/KangJKJK/sonic-checkin/main/package-lock.json

# npm 설치 여부 확인
echo -e "${YELLOW}필요한 파일들을 설치합니다...${NC}"
if ! command -v npm &> /dev/null; then
    echo -e "${RED}npm이 설치되지 않았습니다. npm을 설치합니다...${NC}"
    sudo apt-get update
    sudo apt-get install -y npm
else
    echo -e "${GREEN}npm이 이미 설치되어 있습니다.${NC}"
fi

# Node.js 모듈 설치
echo -e "${YELLOW}필요한 Node.js 모듈을 설치합니다...${NC}"
npm install
npm install @solana/web3.js chalk bs58

# 개인키 입력받기
read -p "Solana의 개인키를 쉼표로 구분하여 입력하세요: " privkeys

# 개인키를 파일에 저장
echo "$privkeys" > "$workDir2/sonicprivate.txt"

# 파일 생성 확인
if [ -f "$workDir2/sonicprivate.txt" ]; then
    echo -e "${GREEN}개인키 파일이 성공적으로 생성되었습니다.${NC}"
else
    echo -e "${RED}개인키 파일 생성에 실패했습니다.${NC}"
fi

# Node.js 스크립트 작성 (sonic-daily.mjs)
echo -e "${YELLOW}Node.js 스크립트를 작성하고 있습니다...${NC}"
cat << 'EOF' > sonic-daily.mjs
// sonic-daily.mjs
import path from 'path';
import fs from 'fs';
import { Connection, Keypair, Transaction } from '@solana/web3.js';
import bs58 from 'bs58';
import nacl from 'tweetnacl';
import fetch from 'node-fetch';

// 작업 디렉토리 설정
const workDir2 = '/root/sonic-daily';
if (!fs.existsSync(workDir2)) {
    fs.mkdirSync(workDir2, { recursive: true });
}
process.chdir(workDir2);

// 개인키 목록 읽기
const listAccounts = fs.readFileSync(path.join(workDir2, 'sonicprivate.txt'), 'utf-8')
    .split(",")
    .map(a => a.trim());

if (listAccounts.length === 0) {
    throw new Error('sonicprivate.txt에 개인키를 하나 이상 입력해주세요.');
}

// Solana 네트워크에 연결 설정
const connection = new Connection('https://devnet.sonic.game/', 'confirmed');

// 기본 헤더 설정
const defaultHeaders = {
    'accept': '*/*',
    'accept-language': 'en-US,en;q=0.7',
    'content-type': 'application/json',
};

// 개인키로부터 Keypair 객체를 생성하는 함수
function getKeypairFromPrivateKey(privateKey) {
    const decoded = bs58.decode(privateKey);
    return Keypair.fromSecretKey(decoded);
}

// 거래를 보내는 함수
async function sendTransaction(transaction, keyPair) {
    try {
        transaction.partialSign(keyPair);
        const rawTransaction = transaction.serialize();
        const signature = await connection.sendRawTransaction(rawTransaction);
        await connection.confirmTransaction(signature);
        console.log(`트랜잭션 해시: ${signature}`);
        return signature;
    } catch (error) {
        console.error('트랜잭션 전송 오류:', error);
        return error;
    }
}

// 지연을 위한 함수 (초 단위)
const delay = (seconds) => new Promise((resolve) => setTimeout(resolve, seconds * 1000));

// 로그인 토큰을 가져오는 함수
const getLoginToken = async (keyPair) => {
    let success = false;
    while (!success) {
        try {
            const message = await fetch(`https://odyssey-api.sonic.game/auth/sonic/challenge?wallet=${keyPair.publicKey.toBase58()}`, {
                headers: {
                    'accept': '*/*',
                    'accept-language': 'en-US,en;q=0.7',
                    'if-none-match': 'W/"192-D/PuxxsvlPPenys+YyKzNiw6SKg"',
                    'origin': 'https://odyssey.sonic.game',
                    'priority': 'u=1, i',
                    'referer': 'https://odyssey.sonic.game/',
                    'sec-ch-ua': '"Not/A)Brand";v="8", "Chromium";v="126", "Brave";v="126"',
                    'sec-ch-ua-mobile': '?0',
                    'sec-ch-ua-platform': '"Windows"',
                    'sec-fetch-dest': 'empty',
                    'sec-fetch-mode': 'cors',
                    'sec-fetch-site': 'same-site',
                    'sec-gpc': '1',
                    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
                }
            }).then(res => res.json());

            const sign = nacl.sign.detached(Buffer.from(message.data), keyPair.secretKey);
            const signature = Buffer.from(sign).toString('base64');
            const publicKey = keyPair.publicKey.toBase58();
            const addressEncoded = Buffer.from(keyPair.publicKey.toBytes()).toString("base64");
            const authorize = await fetch('https://odyssey-api.sonic.game/auth/sonic/authorize', {
                method: 'POST',
                headers: {
                    'accept': '*/*',
                    'accept-language': 'en-US,en;q=0.7',
                    'content-type': 'application/json',
                    'origin': 'https://odyssey.sonic.game',
                    'priority': 'u=1, i',
                    'referer': 'https://odyssey.sonic.game/',
                    'sec-ch-ua': '"Not/A)Brand";v="8", "Chromium";v="126", "Brave";v="126"',
                    'sec-ch-ua-mobile': '?0',
                    'sec-ch-ua-platform': '"Windows"',
                    'sec-fetch-dest': 'empty',
                    'sec-fetch-mode': 'cors',
                    'sec-fetch-site': 'same-site',
                    'sec-gpc': '1',
                    'user-agent': 'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0.0.0 Safari/537.36'
                },
                body: JSON.stringify({
                    'address': publicKey,
                    'address_encoded': addressEncoded,
                    'signature': signature
                })
            }).then(res => res.json());

            const token = authorize.data.token;
            success = true;
            return token;
        } catch (e) {
            console.error('로그인 토큰 오류:', e);
            // 오류 발생 시 재시도합니다.
            await new Promise(resolve => setTimeout(resolve, 1000)); // 1초 지연 후 재시도
        }
    }
};

// 일일 마일스톤 보상을 클레임하는 함수
const dailyMilestone = async (auth, stage) => {
    let success = false;
    while (!success) {
        try {
            await fetch('https://odyssey-api.sonic.game/user/transactions/state/daily', {
                method: 'GET',
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                }
            });

            const response = await fetch('https://odyssey-api.sonic.game/user/transactions/rewards/claim', {
                method: 'POST',
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                },
                body: JSON.stringify({ 'stage': stage })
            });

            // 응답 상태 확인
            if (!response.ok) {
                throw new Error(`HTTP error! status: ${response.status}`);
            }

            const text = await response.text();
            let data;

            try {
                data = JSON.parse(text);
            } catch (e) {
                throw new Error('응답이 JSON 형식이 아닙니다.');
            }

            if (data.message === 'interact rewards already claimed') {
                success = true;
                return `마일스톤 ${stage} 이미 클레임했습니다!`;
            }

            if (data.data) {
                success = true;
                console.log(`일일 마일스톤 보상 클레임 성공: ${data.data.transactionHash}`);
                return `성공적으로 마일스톤 ${stage} 보상을 클레임했습니다.`;
            }
        } catch (e) {
            console.error('일일 마일스톤 클레임 오류:', e.message);
            // 오류 발생 시 재시도합니다.
        }
    }
};

// 미스터리 박스를 열고 보상을 확인하는 함수
const openBox = async (keyPair, auth) => {
    let success = false;
    while (!success) {
        try {
            const data = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/build-tx', {
                headers: {
                    ...defaultHeaders,
                    'authorization': auth
                }
            }).then(res => res.json());

            if (data.data) {
                const transactionBuffer = Buffer.from(data.data.hash, "base64");
                const transaction = Transaction.from(transactionBuffer);
                transaction.partialSign(keyPair);
                const signature = await sendTransaction(transaction, keyPair);

                const open = await fetch('https://odyssey-api.sonic.game/user/rewards/mystery-box/open', {
                    method: 'POST',
                    headers: {
                        ...defaultHeaders,
                        'authorization': auth
                    },
                    body: JSON.stringify({ 'hash': signature })
                }).then(res => res.json());

                success = true;
                console.log(`미스터리 박스 개봉 트랜잭션 해시: ${signature}`);
                return `성공적으로 미스터리 박스를 열었습니다, ${open.data.reward}!`;
            }
        } catch (e) {
            console.error('미스터리 박스 개봉 오류:', e);
            // 오류 발생 시 재시도합니다.
        }
    }
};

// 결과 기록을 위한 상태 객체
const twisters = {
    put: (key, value) => {
        console.log(`기록 - ${key}:`, value);
        // 실제 구현에서는 파일이나 데이터베이스에 저장할 수 있음
    }
};

// 옵션 객체
const q = {
    openBox: true // 미스터리 박스를 열지 여부 설정
};

// 개인키 처리 및 결과 기록
(async () => {
    const totalKeys = listAccounts.length;
    for (let index = 0; index < totalKeys; index++) {
        const privateKey = listAccounts[index];
        const keypair = getKeypairFromPrivateKey(privateKey);
        const publicKey = keypair.publicKey.toBase58();
        console.log(`지갑 주소: ${publicKey}`);
        const progress = ((index + 1) / totalKeys * 100).toFixed(2);
        console.log(`처리 진행 상태: ${progress}% (${index + 1}/${totalKeys})`);

        // 로그인 토큰 가져오기
        const auth = await getLoginToken(keypair);

        // CLAIM MILESTONES
        twisters.put(`${publicKey}`, { 
            text: ` === ACCOUNT ${(index + 1)} ===
Address      : ${publicKey}
Status       : Try to claim milestones...`
        });

        for (let i = 1; i <= 3; i++) {
            const milestones = await dailyMilestone(auth, i);
            twisters.put(`${publicKey}`, { 
                text: ` === ACCOUNT ${(index + 1)} ===
Address      : ${publicKey}
Status       : ${milestones}`
            });
            await delay(5); // 요청 사이의 지연 시간 설정
        }

        // 결과 기록
        let msg = '작업 완료';

        if (q.openBox) {
            const info = await getUserInfo(auth);
            const totalBox = info.ring_monitor;
            twisters.put(`${publicKey}`, { 
                text: `=== ACCOUNT ${(index + 1)} ===
Address      : ${publicKey}
Status       : Preparing to open ${totalBox} Mystery Box...`
            });

            for (let i = 0; i < totalBox; i++) {
                const openedBox = await openBox(keypair, auth);
                twisters.put(`${publicKey}`, { 
                    text: ` === ACCOUNT ${(index + 1)} ===
Address      : ${publicKey}
Status       : [${(i + 1)}/${totalBox}] You got ${openedBox}!`
                });
                await delay(5); // 요청 사이의 지연 시간 설정
            }

            msg = `Earned Points\nYou have Mystery Box now.`;
        }

// 결과 기록
twisters.put(`${publicKey}`, { 
    active: false,
    text: ` === ACCOUNT ${(index + 1)} ===
Address      : ${publicKey}
Status       : ${msg}`
});

        await new Promise(resolve => setTimeout(resolve, 5000)); // 5초 대기 후 다음 개인키를 처리합니다.
    }
})();
EOF

echo -e "${YELLOW}Node.js 스크립트를 작성했습니다.${NC}"

# Node.js 스크립트 실행
echo -e "${GREEN}Node.js 스크립트를 실행합니다...${NC}"
node --no-deprecation sonic-daily.mjs

echo -e "${GREEN}모든 작업이 완료되었습니다. 컨트롤+A+D로 스크린을 종료해주세요.${NC}"
echo -e "${GREEN}스크립트 작성자: https://t.me/kjkresearch${NC}"
