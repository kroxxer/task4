<?php

namespace App\Controller;

use App\Entity\User;
use App\Form\UserType;
use App\Repository\UserRepository;
use Doctrine\ORM\EntityManager;
use Doctrine\ORM\EntityManagerInterface;
use Symfony\Bundle\FrameworkBundle\Controller\AbstractController;
use Symfony\Bundle\SecurityBundle\Security;
use Symfony\Component\HttpFoundation\RedirectResponse;
use Symfony\Component\HttpFoundation\Request;
use Symfony\Component\HttpFoundation\Response;
use Symfony\Component\Routing\Attribute\Route;
use Symfony\Component\Routing\Generator\UrlGeneratorInterface;

#[Route('/users')]
class UserController extends AbstractController
{
    #[Route('/', name: 'app_user_index')]
    public function index(Request $request, UserRepository $userRepository): Response
    {

        return $this->render('user/index.html.twig', [
            'users' => $userRepository->findAll()
        ]);
    }

    #[Route('/delete', name: 'app_user_delete', methods: ['POST'])]
    public function delete(Request $request, UserRepository $userRepository, EntityManagerInterface $entityManager): Response
    {
        $postData = json_decode($request->getContent());

        foreach ($postData as $data){
            $user = $userRepository->findOneBy(array('id' => $data));
            $entityManager->remove($user);
        }
        $entityManager->flush();

        return new Response();
    }

    #[Route('/ban', name: 'app_user_ban', methods: ['POST'])]
    public function ban(Request $request, EntityManagerInterface $entityManager, UserRepository $userRepository, Security $security): Response
    {
        $postData = json_decode($request->getContent());
        $isLogout = false;
        foreach ($postData as $data){
            $user = $userRepository->findOneBy(array('id' => $data));

            if ($this->getUser()->getId() === intval($data))
                $isLogout = true;

            $user->setBlocked(true);
            $entityManager->persist($user);
        }
        $entityManager->flush();

        if ($isLogout)
            return $security->logout(false);
        else
            return new Response();
    }

    #[Route('/unban', name: 'app_user_unban', methods: ['POST'])]
    public function unban(Request $request, EntityManagerInterface $entityManager, UserRepository $userRepository, UrlGeneratorInterface $urlGenerator): Response
    {
        $postData = json_decode($request->getContent());

        foreach ($postData as $data) {
            $user = $userRepository->findOneBy(array('id' => $data));
            $user->setBlocked(false);
            $entityManager->persist($user);
        }
        $entityManager->flush();

        return new Response();
    }
}
